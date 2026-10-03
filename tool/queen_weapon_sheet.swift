#!/usr/bin/env swift
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let themes = [
  "achaemenid", "arab", "ayodhya", "aztec", "camelot", "chinese",
  "chola", "egyptian", "english", "french", "inca", "japanese",
  "kishkindha", "lanka", "macedonian", "maratha", "mewar", "mongolian",
  "ottoman", "persian", "roman", "sparta", "troy", "zulu",
]
private let cell = 256
private let columns = 6
private let rows = 8

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

func load(_ path: String) -> CGImage {
  guard let source = CGImageSourceCreateWithURL(
    URL(fileURLWithPath: path) as CFURL,
    nil
  ), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("Could not decode \(path)")
  }
  return image
}

func context(width: Int, height: Int) -> CGContext {
  guard let value = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { fail("Could not create bitmap context") }
  value.interpolationQuality = .high
  return value
}

func write(_ image: CGImage, to path: String) {
  try? FileManager.default.createDirectory(
    at: URL(fileURLWithPath: path).deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  guard let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: path) as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
  ) else { fail("Could not create \(path)") }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else {
    fail("Could not write \(path)")
  }
}

func destinationRect(index: Int) -> CGRect {
  let column = index % columns
  let topRow = index / columns
  return CGRect(
    x: column * cell,
    y: (rows - 1 - topRow) * cell,
    width: cell,
    height: cell
  )
}

guard CommandLine.arguments.count == 4 else {
  fail("Usage: queen_weapon_sheet.swift extract|apply ASSET_DIR INPUT_OR_OUTPUT")
}

let mode = CommandLine.arguments[1]
let assetDirectory = CommandLine.arguments[2]
let path = CommandLine.arguments[3]

if mode == "extract" {
  let output = context(width: columns * cell, height: rows * cell)
  for (themeIndex, theme) in themes.enumerated() {
    let atlas = load("\(assetDirectory)/\(theme)-v1.png")
    guard atlas.width == 1536, atlas.height == 512 else {
      fail("Unexpected atlas dimensions for \(theme)")
    }
    for side in 0..<2 {
      guard let queen = atlas.cropping(
        to: CGRect(x: cell, y: side * cell, width: cell, height: cell)
      ) else { fail("Could not crop \(theme) side \(side)") }
      output.draw(queen, in: destinationRect(index: themeIndex * 2 + side))
    }
  }
  guard let image = output.makeImage() else { fail("Could not create sheet") }
  write(image, to: path)
  print("Extracted 48 Queens to \(path)")
} else if mode == "apply" {
  let edited = load(path)
  guard edited.width == columns * cell, edited.height == rows * cell else {
    fail("Edited sheet must be 1536x2048")
  }
  let outputDirectory = URL(fileURLWithPath: path).deletingLastPathComponent()
    .appendingPathComponent("atlases").path
  try? FileManager.default.createDirectory(
    atPath: outputDirectory,
    withIntermediateDirectories: true
  )
  for (themeIndex, theme) in themes.enumerated() {
    let atlas = load("\(assetDirectory)/\(theme)-v1.png")
    let output = context(width: atlas.width, height: atlas.height)
    output.draw(atlas, in: CGRect(x: 0, y: 0, width: atlas.width, height: atlas.height))
    for side in 0..<2 {
      let sheetIndex = themeIndex * 2 + side
      let sourceTopRow = sheetIndex / columns
      guard let queen = edited.cropping(
        to: CGRect(
          x: (sheetIndex % columns) * cell,
          y: sourceTopRow * cell,
          width: cell,
          height: cell
        )
      ) else { fail("Could not crop edited \(theme) side \(side)") }
      output.clear(CGRect(x: cell, y: (1 - side) * cell, width: cell, height: cell))
      output.draw(
        queen,
        in: CGRect(x: cell, y: (1 - side) * cell, width: cell, height: cell)
      )
    }
    guard let image = output.makeImage() else { fail("Could not create \(theme)") }
    write(image, to: "\(outputDirectory)/\(theme)-v1.png")
  }
  print("Prepared 24 Queen-updated atlases in \(outputDirectory)")
} else {
  fail("Mode must be extract or apply")
}
