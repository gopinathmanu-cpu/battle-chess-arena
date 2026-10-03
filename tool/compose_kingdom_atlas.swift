// SPDX-License-Identifier: GPL-3.0-or-later
// Replace the advisor/fortress artwork with user-requested mounted warriors.
// Usage: swift tool/compose_kingdom_atlas.swift BASE.png ELEPHANTS.png CHARIOTS.png ROW OUTPUT.png
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
func readImage(_ path: String, width: Int, height: Int) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == width, image.height == height else {
        fail("Expected \(width)x\(height) prepared atlas: \(path)")
    }
    return image
}
let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 5, let row = Int(args[3]), (0..<4).contains(row) else {
    fail("Usage: compose_kingdom_atlas.swift BASE.png ELEPHANTS.png CHARIOTS.png ROW(0-3) OUTPUT.png")
}
let outputURL = URL(fileURLWithPath: args[4])
guard !FileManager.default.fileExists(atPath: outputURL.path) else {
    fail("Refusing to replace an existing atlas; select a new versioned output: \(args[4])")
}
let base = readImage(args[0], width: 1536, height: 512)
let elephants = readImage(args[1], width: 512, height: 1024)
let chariots = readImage(args[2], width: 512, height: 1024)
guard let context = CGContext(data: nil, width: 1536, height: 512,
    bitsPerComponent: 8, bytesPerRow: 1536 * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fail("Unable to allocate output atlas")
}
context.interpolationQuality = .high
context.draw(base, in: CGRect(x: 0, y: 0, width: 1536, height: 512))
for side in 0..<2 {
    for (column, image) in [(2, elephants), (4, chariots)] {
        let sourceRect = CGRect(x: side * 256, y: row * 256, width: 256, height: 256)
        guard let sprite = image.cropping(to: sourceRect) else { fail("Invalid source cell") }
        let destination = CGRect(x: column * 256, y: (1 - side) * 256,
                                 width: 256, height: 256)
        context.clear(destination)
        context.draw(sprite, in: destination)
    }
}
guard let output = context.makeImage() else { fail("Cannot render output") }
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL,
    UTType.png.identifier as CFString, 1, nil) else { fail("Cannot create output file") }
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fail("Cannot write output file") }
print("Saved \(args[4]) with elephant bishops and chariot rooks for both armies.")
