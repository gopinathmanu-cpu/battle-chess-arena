#!/usr/bin/env swift
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation
import ImageIO

private let editedThemes = [
  "achaemenid", "arab", "ayodhya", "aztec", "camelot", "chinese",
  "chola", "egyptian", "english", "french", "inca", "japanese",
  "kishkindha", "lanka", "macedonian", "maratha", "mewar", "mongolian",
  "ottoman", "persian", "roman", "sparta", "troy", "zulu",
]
private let untouchedThemes = ["asgard", "atlantis", "hastinapura"]

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

func load(_ path: String) -> (CGImage, [UInt8]) {
  guard let source = CGImageSourceCreateWithURL(
    URL(fileURLWithPath: path) as CFURL,
    nil
  ), let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
    image.width == 1536, image.height == 512
  else { fail("Missing or invalid atlas: \(path)") }
  var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
  guard let canvas = CGContext(
    data: &pixels,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: image.width * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { fail("Could not rasterize \(path)") }
  canvas.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  return (image, pixels)
}

guard CommandLine.arguments.count == 3 else {
  fail("Usage: verify_queen_weapon_atlases.swift BEFORE_DIR AFTER_DIR")
}
let beforeDirectory = CommandLine.arguments[1]
let afterDirectory = CommandLine.arguments[2]

for theme in editedThemes {
  let (_, before) = load("\(beforeDirectory)/\(theme)-v1.png")
  let (_, after) = load("\(afterDirectory)/\(theme)-v1.png")
  var queenChanged = false
  for y in 0..<512 {
    for x in 0..<1536 {
      let offset = (y * 1536 + x) * 4
      let same = before[offset..<(offset + 4)].elementsEqual(after[offset..<(offset + 4)])
      if (256..<512).contains(x) {
        queenChanged = queenChanged || !same
      } else if !same {
        fail("Non-Queen pixel changed in \(theme) at \(x),\(y)")
      }
    }
  }
  if !queenChanged { fail("Queen cells did not change in \(theme)") }
}

for theme in untouchedThemes {
  let (_, before) = load("\(beforeDirectory)/\(theme)-v1.png")
  let (_, after) = load("\(afterDirectory)/\(theme)-v1.png")
  if before != after { fail("Already-armed atlas changed: \(theme)") }
}

print("Verified Queen-only pixel changes in 24 atlases; 3 armed atlases unchanged.")
