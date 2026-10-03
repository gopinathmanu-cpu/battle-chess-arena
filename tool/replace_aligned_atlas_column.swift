#!/usr/bin/env swift
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

guard CommandLine.arguments.count == 5,
      let column = Int(CommandLine.arguments[4]),
      (0..<6).contains(column) else {
  fail("Usage: replace_aligned_atlas_column.swift BASE.png REPLACEMENT.png OUTPUT.png COLUMN")
}

func load(_ path: String) -> CGImage {
  let url = URL(fileURLWithPath: path) as CFURL
  guard let source = CGImageSourceCreateWithURL(url, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("Could not decode \(path)")
  }
  return image
}

let base = load(CommandLine.arguments[1])
let replacement = load(CommandLine.arguments[2])
guard base.width == 1536, base.height == 2048,
      replacement.width == base.width, replacement.height == base.height else {
  fail("Both atlases must be 1536x2048")
}

let bytesPerPixel = 4
let bytesPerRow = base.width * bytesPerPixel
let colorSpace = CGColorSpaceCreateDeviceRGB()

func pixels(for image: CGImage) -> [UInt8] {
  var pixels = [UInt8](repeating: 0, count: image.height * bytesPerRow)
  guard let context = CGContext(
    data: &pixels,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { fail("Could not create bitmap context") }
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  return pixels
}

var outputPixels = pixels(for: base)
let replacementPixels = pixels(for: replacement)
let minX = column * 256
let maxX = minX + 256

for y in 0..<base.height {
  for x in minX..<maxX {
    let index = (y * base.width + x) * bytesPerPixel
    let alpha = replacementPixels[index + 3]
    if alpha < 42 {
      outputPixels[index] = 0
      outputPixels[index + 1] = 0
      outputPixels[index + 2] = 0
      outputPixels[index + 3] = 0
    } else {
      outputPixels[index] = replacementPixels[index]
      outputPixels[index + 1] = replacementPixels[index + 1]
      outputPixels[index + 2] = replacementPixels[index + 2]
      outputPixels[index + 3] = alpha
    }
  }
}

guard let outputContext = CGContext(
  data: &outputPixels,
  width: base.width,
  height: base.height,
  bitsPerComponent: 8,
  bytesPerRow: bytesPerRow,
  space: colorSpace,
  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
), let output = outputContext.makeImage(),
   let destination = CGImageDestinationCreateWithURL(
     URL(fileURLWithPath: CommandLine.arguments[3]) as CFURL,
     UTType.png.identifier as CFString,
     1,
     nil
   ) else { fail("Could not create output atlas") }

CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fail("Could not write output atlas") }
print("Replaced atlas column \(column) in \(CommandLine.arguments[3])")
