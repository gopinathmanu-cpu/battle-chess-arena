// SPDX-License-Identifier: GPL-3.0-or-later
// Lossless platform export only: composite the unchanged transparent master
// over ivory for the iOS asset catalog, which uses opaque RGB icons.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Usage: flatten_launcher_icon.swift source.png output.png")
}
let width = image.width
let height = image.height
guard let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8,
    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Unable to allocate RGB icon")
}
context.interpolationQuality = .high
let bounds = CGRect(x: 0, y: 0, width: width, height: height)
context.setFillColor(red: 1, green: 0.98, blue: 0.94, alpha: 1)
context.fill(bounds)
context.draw(image, in: bounds)
guard let flattened = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: arguments[2]) as CFURL,
        UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Unable to encode RGB icon")
}
CGImageDestinationAddImage(destination, flattened, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Unable to write RGB icon")
}
