// SPDX-License-Identifier: GPL-3.0-or-later
// Requires macOS 14+ and Xcode command-line tools. All processing stays local.
// swift tool/prepare_custom_piece_atlas.swift [source.png] [output.png]
// Keeps the original atlas coordinates and removes backgrounds with Vision's
// foreground-instance segmentation, never by replacing an artwork colour.
import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

let arguments = Array(CommandLine.arguments.dropFirst())
let inputPath = arguments.first ?? "assets/custom_sets/modular-parts-source-v1.png"
let outputPath = arguments.count > 1 ? arguments[1] : "assets/custom_sets/modular-parts-v1.png"
let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)
guard inputURL.standardizedFileURL != outputURL.standardizedFileURL else {
    fatalError("Keep the original source unchanged; input and output must differ.")
}
guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let source = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
    fatalError("Cannot open atlas source: \(inputPath)")
}
guard source.width == 1024 && source.height == 1536 else {
    fatalError("Measured bounds require the original 1024 x 1536 source.")
}

// Same measured bounds as CustomPieceParts in custom_piece.dart.
let bounds: [[Int]] = [
    [14, 25, 265, 246], [266, 25, 508, 246], [516, 25, 758, 246], [770, 25, 1008, 246],
    [39, 253, 239, 523], [292, 253, 476, 523], [550, 253, 717, 523], [810, 253, 975, 523],
    [52, 533, 224, 765], [299, 533, 466, 765], [527, 533, 742, 765], [779, 533, 996, 765],
    [32, 784, 246, 953], [284, 784, 486, 945], [525, 784, 748, 953], [794, 767, 988, 953],
    [87, 959, 189, 1225], [330, 947, 440, 1224], [609, 956, 655, 1218], [865, 962, 981, 1225],
    [37, 1229, 238, 1511], [284, 1228, 485, 1511], [529, 1219, 741, 1511], [775, 1229, 990, 1511],
]
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
guard let output = CGContext(
    data: nil, width: source.width, height: source.height,
    bitsPerComponent: 8, bytesPerRow: source.width * 4,
    space: colorSpace, bitmapInfo: bitmapInfo
) else { fatalError("Cannot allocate atlas canvas.") }
let ciContext = CIContext()

for (index, value) in bounds.enumerated() {
    try autoreleasepool {
        let region = CGRect(x: value[0], y: value[1], width: value[2] - value[0], height: value[3] - value[1])
        guard let crop = source.cropping(to: region) else { fatalError("Cannot crop part \(index).") }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: crop, options: [:])
        try handler.perform([request])
        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            fatalError("No foreground found for part \(index); inspect before shipping.")
        }
        let buffer = try result.generateScaledMaskForImage(
            forInstances: result.allInstances, from: handler
        )
        let original = CIImage(cgImage: crop)
        // Use Vision only for alpha, never for foreground colour. This avoids
        // decontamination artefacts around skin, hair and polished metal.
        let cutout = original.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: original.extent),
            kCIInputMaskImageKey: CIImage(cvPixelBuffer: buffer),
        ])
        guard let image = ciContext.createCGImage(cutout, from: cutout.extent) else {
            fatalError("Cannot render foreground for part \(index).")
        }
        let target = CGRect(x: region.minX, y: CGFloat(source.height) - region.maxY,
                            width: region.width, height: region.height)
        output.draw(image, in: target)
        print("Prepared part \(index + 1)/\(bounds.count)")
        fflush(stdout)
    }
}

guard let pixels = output.data?.assumingMemoryBound(to: UInt8.self) else { fatalError("Cannot finish atlas.") }
let pixelCount = source.width * source.height
var transparent = 0
var opaque = 0
for index in 0..<pixelCount {
    var alpha = pixels[index * 4 + 3]
    // Discard very-low-confidence fringe pixels. RGB is untouched everywhere
    // else; this removes coloured segmentation speckles, not skin or armour.
    if alpha < 24 {
        pixels[index * 4] = 0
        pixels[index * 4 + 1] = 0
        pixels[index * 4 + 2] = 0
        pixels[index * 4 + 3] = 0
        alpha = 0
    }
    if alpha < 8 { transparent += 1 }
    if alpha > 247 { opaque += 1 }
}
guard transparent > pixelCount / 3 && opaque > pixelCount / 10 else {
    fatalError("Suspicious alpha distribution: transparent=\(transparent), opaque=\(opaque).")
}
guard let completed = output.makeImage() else { fatalError("Cannot finish atlas.") }
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Cannot create output PNG.")
}
CGImageDestinationAddImage(destination, completed, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write output PNG.") }
print("Saved \(outputPath): \(transparent) transparent, \(opaque) opaque pixels out of \(pixelCount).")
