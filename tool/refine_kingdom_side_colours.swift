#!/usr/bin/env swift
// SPDX-License-Identifier: GPL-3.0-or-later
// Refines the shipped Historical/Legendary 2x6 atlases without changing alpha,
// geometry, orientation, Queen weapons, or any source outside the owned cells.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ??
  "assets/characters/kingdoms", isDirectory: true)
let manager = FileManager.default
let inputs = try manager.contentsOfDirectory(at: directory,
  includingPropertiesForKeys: nil)
  .filter { $0.lastPathComponent.hasSuffix("-v2.png") }
  .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard inputs.count == 27 else { fail("Expected 27 v2 kingdom atlases, found \(inputs.count)") }

let colourSpace = CGColorSpace(name: CGColorSpace.sRGB)!
for input in inputs {
  guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        image.width == 1536, image.height == 512 else {
    fail("Invalid kingdom atlas: \(input.path)")
  }
  var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
  guard let context = CGContext(data: &pixels, width: image.width,
    height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
    space: colourSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { fail("Cannot allocate bitmap for \(input.path)") }
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

  for y in 0..<image.height {
    let sourceRow = y / 256
    let localY = y % 256
    for x in 0..<image.width {
      let column = x / 256
      let index = (y * image.width + x) * 4
      let alpha = Int(pixels[index + 3])
      if alpha < 24 { continue }
      var red = Double(pixels[index])
      var green = Double(pixels[index + 1])
      var blue = Double(pixels[index + 2])
      let maximum = max(red, green, blue)
      let minimum = min(red, green, blue)
      let saturation = maximum == 0 ? 0 : (maximum - minimum) / maximum
      let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

      // White elephant/horse cells only. Below the rider's torso, neutral grey
      // mount material becomes cool ivory while saturated blue/gold tack stays.
      if sourceRow == 0 && (column == 2 || column == 3) && localY >= 58 &&
          saturation < 0.29 && luminance > 34 && luminance < 232 {
        let shade = max(176.0, min(250.0, 174.0 + luminance * 0.34))
        let strength = saturation < 0.15 ? 0.82 : 0.62
        red += (shade + 4 - red) * strength
        green += (shade + 5 - green) * strength
        blue += (shade + 9 - blue) * strength
      }

      // Black army: preserve true black, but make existing crimson, gold and
      // warm skin accents vivid enough to read at phone-board size.
      if sourceRow == 1 && column != 1 && luminance > 24 && luminance < 155 &&
          saturation > 0.24 {
        let gold = red > green * 1.04 && green > blue * 1.16 && green > red * 0.54
        let crimson = red > green * 1.34 && red > blue * 1.18
        if gold {
          red = min(255, red * 1.14 + 7)
          green = min(255, green * 1.28 + 9)
          blue *= 0.82
        } else if crimson {
          red = min(255, red * 1.28 + 10)
          green *= 0.92
          blue *= 0.94
        }
      }
      pixels[index] = UInt8(max(0, min(255, red.rounded())))
      pixels[index + 1] = UInt8(max(0, min(255, green.rounded())))
      pixels[index + 2] = UInt8(max(0, min(255, blue.rounded())))
    }
  }

  guard let outputImage = context.makeImage() else { fail("Cannot finish \(input.path)") }
  let output = input.deletingPathExtension().deletingLastPathComponent()
    .appendingPathComponent(input.deletingPathExtension().lastPathComponent
      .replacingOccurrences(of: "-v2", with: "-v3") + ".png")
  guard let destination = CGImageDestinationCreateWithURL(output as CFURL,
    UTType.png.identifier as CFString, 1, nil) else { fail("Cannot create \(output.path)") }
  CGImageDestinationAddImage(destination, outputImage, nil)
  guard CGImageDestinationFinalize(destination) else { fail("Cannot save \(output.path)") }
  print("Saved \(output.lastPathComponent)")
}
