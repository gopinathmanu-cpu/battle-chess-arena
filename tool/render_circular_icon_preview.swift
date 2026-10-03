#!/usr/bin/env swift
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3,
      let source = CGImageSourceCreateWithURL(
        URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL,
        nil
      ),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let context = CGContext(
        data: nil,
        width: 512,
        height: 512,
        bitsPerComponent: 8,
        bytesPerRow: 512 * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
  fatalError("Usage: render_circular_icon_preview.swift INPUT.png OUTPUT.png")
}

let bounds = CGRect(x: 0, y: 0, width: 512, height: 512)
context.addEllipse(in: bounds)
context.clip()
context.interpolationQuality = .high
context.draw(image, in: bounds)

guard let output = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      ) else {
  fatalError("Unable to create circular preview")
}
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else {
  fatalError("Unable to save circular preview")
}
