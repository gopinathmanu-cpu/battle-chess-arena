// SPDX-License-Identifier: GPL-3.0-or-later
// Assemble exactly twelve reviewed, prepared 256px cells without redrawing.
// Usage: swift tool/assemble_kingdom_cells.swift CELLS.json OUTPUT.png
// Manifest: {"cells":[{"path":"...png","column":0,"row":0}, ...]}
// Order: White K,Q,B,N,R,P, Black K,Q,B,N,R,P; paths relative to cwd.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1)
}
let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 2 else { fail("Expected CELLS.json OUTPUT.png") }
let outputURL = URL(fileURLWithPath: args[1])
guard !FileManager.default.fileExists(atPath: outputURL.path) else {
    fail("Refusing to overwrite existing output: \(args[1])")
}
let data = try Data(contentsOf: URL(fileURLWithPath: args[0]))
guard let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let cells = manifest["cells"] as? [[String: Any]], cells.count == 12 else {
    fail("Manifest must describe exactly twelve cells")
}
guard let canvas = CGContext(data: nil, width: 1536, height: 512,
    bitsPerComponent: 8, bytesPerRow: 1536 * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fail("Unable to allocate canvas")
}
canvas.interpolationQuality = .none
var images = [String: CGImage]()
for (index, cell) in cells.enumerated() {
    guard let path = cell["path"] as? String,
          let column = cell["column"] as? Int, let row = cell["row"] as? Int,
          column >= 0, row >= 0 else { fail("Invalid cell \(index)") }
    if images[path] == nil {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width % 256 == 0, image.height % 256 == 0 else {
            fail("Not a prepared 256px-cell atlas: \(path)")
        }
        images[path] = image
    }
    let image = images[path]!
    guard column < image.width / 256, row < image.height / 256,
          let sprite = image.cropping(to: CGRect(x: column * 256, y: row * 256,
              width: 256, height: 256)) else { fail("Cell out of range: \(index)") }
    canvas.draw(sprite, in: CGRect(x: (index % 6) * 256,
        y: (1 - index / 6) * 256, width: 256, height: 256))
}
guard let completed = canvas.makeImage() else { fail("Cannot render atlas") }
let png = NSMutableData()
guard let destination = CGImageDestinationCreateWithData(png,
    UTType.png.identifier as CFString, 1, nil) else { fail("Cannot encode atlas") }
CGImageDestinationAddImage(destination, completed, nil)
guard CGImageDestinationFinalize(destination) else { fail("PNG encoding failed") }
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true)
try (png as Data).write(to: outputURL, options: .atomic)
print("Saved \(args[1]) from twelve prepared cells")
