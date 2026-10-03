#!/usr/bin/env swift
// SPDX-License-Identifier: GPL-3.0-or-later
// macOS 14+, Xcode command-line tools; local processing only.
//
// swift tool/prepare_kingdom_atlas.swift INPUT.png OUTPUT.png \
//   [--crops CROPS.json] [--columns 6] [--rows 2] [--report REPORT.json] [--overwrite]
//
// CROPS.json uses TOP-LEFT coordinates and exclusive right/bottom bounds:
// {"sourceSize":[1536,1024],"bounds":[[left,top,right,bottom], ... 12 boxes]}
// For a visually reviewed cut directly above an unwanted display plinth,
// optional "allowedEdgeContacts":{"1":["bottom"]} accepts contact for that
// cell and edge only. Accepted contacts are recorded in the QA report.
// Reviewed non-touching silhouettes may have overlapping bounding boxes:
// "allowOverlappingCrops":true and "excludedRects":{"1":[[l,t,r,b],...]}
// explicitly clear neighbouring fragments for each affected cell. Exclusions
// use source-space coordinates, run AFTER segmentation and BEFORE validation,
// and are recorded in the report. They never modify the source image.
// Default order: white K,Q,B,N,R,P, then black K,Q,B,N,R,P. A bare bounds array
// is also accepted. Other layouts use --columns/--rows; boxes are written in
// row-major output order. Rectangles must not overlap.
// Without --crops, approximate grid gutters are found near the requested grid;
// ambiguous gutters are rejected. Inspect generated sheets before preparing.
//
// Existing transparency is preserved. Opaque cells use Vision only for alpha;
// no artwork colour is keyed out, recoloured, or replaced. Subjects are fitted
// within 224×226 on 256×256 cells, centred horizontally, with baseline y=244.
// A sibling .report.json records crop/alpha bounds, scale, mask and QA results.
// No source is changed; output PNG is written atomically only after all checks.

import Foundation
import CoreGraphics
import CoreVideo
import ImageIO
import UniformTypeIdentifiers
import Vision

struct PreparationError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

struct Bounds {
    let left: Int
    let top: Int
    let right: Int
    let bottom: Int
    var width: Int { right - left }
    var height: Int { bottom - top }
    var rect: CGRect { CGRect(x: left, y: top, width: width, height: height) }
    var array: [Int] { [left, top, right, bottom] }
    func intersects(_ other: Bounds) -> Bool {
        min(right, other.right) > max(left, other.left) &&
        min(bottom, other.bottom) > max(top, other.top)
    }
}

struct Component {
    var left = Int.max
    var top = Int.max
    var right = 0
    var bottom = 0
    var pixels = 0
    var indices = [Int]()
    var bounds: Bounds { Bounds(left: left, top: top, right: right, bottom: bottom) }
    mutating func include(_ index: Int, width: Int) {
        let x = index % width, y = index / width
        left = min(left, x); top = min(top, y)
        right = max(right, x + 1); bottom = max(bottom, y + 1)
        pixels += 1
        indices.append(index)
    }
}

let rgbaInfo = CGBitmapInfo.byteOrder32Big.rawValue |
    CGImageAlphaInfo.premultipliedLast.rawValue
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let alphaFloor: UInt8 = 24
let roles = ["king", "queen", "bishop", "knight", "rook", "pawn"]

struct Raster {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(_ image: CGImage) throws {
        let imageWidth = image.width, imageHeight = image.height
        width = imageWidth; height = imageHeight
        var data = [UInt8](repeating: 0, count: imageWidth * imageHeight * 4)
        let rendered = data.withUnsafeMutableBytes { bytes -> Bool in
            guard let canvas = CGContext(data: bytes.baseAddress, width: imageWidth,
                height: imageHeight, bitsPerComponent: 8, bytesPerRow: imageWidth * 4,
                space: sRGB, bitmapInfo: rgbaInfo) else { return false }
            canvas.setBlendMode(.copy)
            canvas.draw(image, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            return true
        }
        guard rendered else { throw PreparationError("Cannot allocate source bitmap.") }
        pixels = data
    }

    func image() throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: sRGB, bitmapInfo: CGBitmapInfo(rawValue: rgbaInfo),
                provider: provider, decode: nil, shouldInterpolate: true,
                intent: .defaultIntent) else {
            throw PreparationError("Cannot construct RGBA bitmap.")
        }
        return image
    }

    var transparentCount: Int {
        stride(from: 3, to: pixels.count, by: 4).reduce(0) {
            $0 + (pixels[$1] < alphaFloor ? 1 : 0)
        }
    }

    // Actual clear pixels, not merely an alpha-channel declaration, identify
    // an existing cutout. A PNG with an all-opaque alpha channel needs Vision.
    var hasMeaningfulAlpha: Bool {
        transparentCount >= max(8, width * height / 200)
    }

    mutating func clear(_ index: Int) {
        for channel in 0..<4 { pixels[index * 4 + channel] = 0 }
    }

    mutating func cleanLowAlpha() -> Int {
        var removed = 0
        for index in 0..<(width * height) where pixels[index * 4 + 3] < alphaFloor {
            if pixels[index * 4 + 3] > 0 { removed += 1 }
            clear(index)
        }
        return removed
    }

    func components() -> [Component] {
        var visited = [Bool](repeating: false, count: width * height)
        var result = [Component]()
        var queue = [Int]()
        for start in 0..<(width * height) {
            if visited[start] || pixels[start * 4 + 3] < alphaFloor { continue }
            queue.removeAll(keepingCapacity: true)
            queue.append(start); visited[start] = true
            var head = 0, component = Component()
            while head < queue.count {
                let index = queue[head]; head += 1
                component.include(index, width: width)
                let x = index % width, y = index / width
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) {
                        let next = ny * width + nx
                        if !visited[next] && pixels[next * 4 + 3] >= alphaFloor {
                            visited[next] = true; queue.append(next)
                        }
                    }
                }
            }
            result.append(component)
        }
        return result.sorted { $0.pixels > $1.pixels }
    }
}

struct Options {
    let input: URL
    let output: URL
    let crops: URL?
    let report: URL
    let overwrite: Bool
    let columns: Int
    let rows: Int
}

func parseOptions() throws -> Options {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count >= 2 else {
        throw PreparationError("Usage: prepare_kingdom_atlas.swift INPUT.png OUTPUT.png [--crops CROPS.json] [--columns 6] [--rows 2] [--report REPORT.json] [--overwrite]")
    }
    var crops: URL?, report: URL?, overwrite = false, index = 2
    var columns = 6, rows = 2
    while index < args.count {
        switch args[index] {
        case "--overwrite": overwrite = true
        case "--crops", "--report", "--columns", "--rows":
            let option = args[index]
            index += 1
            guard index < args.count else { throw PreparationError("Missing value for \(option).") }
            if option == "--crops" { crops = URL(fileURLWithPath: args[index]) }
            else if option == "--report" { report = URL(fileURLWithPath: args[index]) }
            else {
                guard let count = Int(args[index]), (1...16).contains(count) else {
                    throw PreparationError("\(option) must be an integer from 1 through 16.")
                }
                if option == "--columns" { columns = count } else { rows = count }
            }
        default:
            if index == 2 && !args[index].hasPrefix("--") {
                crops = URL(fileURLWithPath: args[index])
            } else { throw PreparationError("Unknown argument: \(args[index])") }
        }
        index += 1
    }
    let input = URL(fileURLWithPath: args[0]).standardizedFileURL.resolvingSymlinksInPath()
    let output = URL(fileURLWithPath: args[1]).standardizedFileURL.resolvingSymlinksInPath()
    let reportURL = (report ?? output.deletingPathExtension().appendingPathExtension("report.json"))
        .standardizedFileURL.resolvingSymlinksInPath()
    let cropsURL = crops?.standardizedFileURL.resolvingSymlinksInPath()
    guard input != output && input != reportURL && output != reportURL &&
          cropsURL != output && cropsURL != reportURL else {
        throw PreparationError("Input, output, crop configuration, and report must be distinct; originals are never overwritten.")
    }
    for destination in [output, reportURL] where !overwrite && FileManager.default.fileExists(atPath: destination.path) {
        throw PreparationError("Refusing to overwrite \(destination.path); pass --overwrite after reviewing the exact target.")
    }
    return Options(input: input, output: output, crops: cropsURL, report: reportURL,
        overwrite: overwrite, columns: columns, rows: rows)
}

func measuredBounds(_ url: URL, source: CGImage, count: Int) throws -> [Bounds] {
    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    let boxes: Any
    if let object = json as? [String: Any] {
        if let size = object["sourceSize"] as? [Int], size != [source.width, source.height] {
            throw PreparationError("Measured sourceSize \(size) does not match \(source.width)×\(source.height).")
        }
        guard let value = object["bounds"] else { throw PreparationError("Crop JSON needs a bounds array.") }
        boxes = value
    } else { boxes = json }
    guard let entries = boxes as? [[Int]], entries.count == count else {
        throw PreparationError("Expected \(count) integer [left,top,right,bottom] bounds in desired row-major output order.")
    }
    return try entries.enumerated().map { index, values in
        guard values.count == 4 else { throw PreparationError("Crop \(index) must have four integers.") }
        let bounds = Bounds(left: values[0], top: values[1], right: values[2], bottom: values[3])
        guard bounds.left >= 0 && bounds.top >= 0 && bounds.right <= source.width &&
              bounds.bottom <= source.height && bounds.width >= 16 && bounds.height >= 16 else {
            throw PreparationError("Crop \(index) is empty, too small, or outside the source: \(values).")
        }
        return bounds
    }
}

func reviewedEdgeContacts(_ url: URL?, count: Int) throws -> [Int: Set<String>] {
    guard let url,
          let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
          let value = object["allowedEdgeContacts"] else { return [:] }
    guard let entries = value as? [String: [String]] else {
        throw PreparationError("allowedEdgeContacts must map cell indices to arrays of reviewed edge names.")
    }
    let validEdges: Set<String> = ["left", "top", "right", "bottom"]
    var result = [Int: Set<String>]()
    for (key, edges) in entries {
        guard let index = Int(key), (0..<count).contains(index),
              !edges.isEmpty, Set(edges).isSubset(of: validEdges) else {
            throw PreparationError("Invalid reviewed edge exception for cell \(key): \(edges).")
        }
        result[index] = Set(edges)
    }
    return result
}

struct ReviewedExclusions {
    let allowOverlappingCrops: Bool
    let rectangles: [Int: [Bounds]]
}

func reviewedExclusions(_ url: URL?, source: CGImage, crops: [Bounds]) throws -> ReviewedExclusions {
    guard let url,
          let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
        return ReviewedExclusions(allowOverlappingCrops: false, rectangles: [:])
    }
    if let value = object["allowOverlappingCrops"], !(value is Bool) {
        throw PreparationError("allowOverlappingCrops must be an explicit boolean.")
    }
    let allowOverlap = object["allowOverlappingCrops"] as? Bool ?? false
    guard let value = object["excludedRects"] else {
        return ReviewedExclusions(allowOverlappingCrops: allowOverlap, rectangles: [:])
    }
    guard let entries = value as? [String: [[Int]]] else {
        throw PreparationError("excludedRects must map cell indices to arrays of source-space rectangles.")
    }
    var result = [Int: [Bounds]]()
    for (key, rectangles) in entries {
        guard let index = Int(key), crops.indices.contains(index), !rectangles.isEmpty else {
            throw PreparationError("Invalid excludedRects cell index or empty rectangle list: \(key).")
        }
        result[index] = try rectangles.map { values in
            guard values.count == 4 else {
                throw PreparationError("Each excluded rectangle in cell \(index) must have four integers.")
            }
            let rect = Bounds(left: values[0], top: values[1], right: values[2], bottom: values[3])
            guard rect.left >= 0, rect.top >= 0, rect.right <= source.width,
                  rect.bottom <= source.height, rect.width > 0, rect.height > 0,
                  rect.intersects(crops[index]) else {
                throw PreparationError("Excluded rectangle \(values) is outside the source, empty, or does not intersect cell \(index).")
            }
            return rect
        }
    }
    return ReviewedExclusions(allowOverlappingCrops: allowOverlap, rectangles: result)
}

func clearReviewedExclusions(_ exclusions: [Bounds], region: Bounds, raster: inout Raster) -> Int {
    var cleared = 0
    for rect in exclusions {
        let left = max(region.left, rect.left) - region.left
        let right = min(region.right, rect.right) - region.left
        let top = max(region.top, rect.top) - region.top
        let bottom = min(region.bottom, rect.bottom) - region.top
        for y in top..<bottom {
            for x in left..<right {
                let index = y * raster.width + x
                if raster.pixels[index * 4 + 3] > 0 { cleared += 1 }
                raster.clear(index)
            }
        }
    }
    return cleared
}

// Background colour is used ONLY to propose crop boundaries for opaque sheets,
// never to remove pixels. Segmentation remains Vision's responsibility.
func automaticBounds(_ image: Raster, columnCount: Int, rowCount: Int) throws -> [Bounds] {
    let w = image.width, h = image.height
    let useAlpha = image.hasMeaningfulAlpha
    var channels = [[Int]](repeating: [], count: 3)
    for y in stride(from: 0, to: h, by: max(1, h / 64)) {
        for x in [0, w - 1] {
            for channel in 0..<3 { channels[channel].append(Int(image.pixels[(y * w + x) * 4 + channel])) }
        }
    }
    for x in stride(from: 0, to: w, by: max(1, w / 64)) {
        for y in [0, h - 1] {
            for channel in 0..<3 { channels[channel].append(Int(image.pixels[(y * w + x) * 4 + channel])) }
        }
    }
    let background = channels.map { values -> Int in
        let sorted = values.sorted(); return sorted[sorted.count / 2]
    }
    func occupied(_ x: Int, _ y: Int) -> Bool {
        let index = (y * w + x) * 4
        if useAlpha { return image.pixels[index + 3] >= alphaFloor }
        return (0..<3).contains { abs(Int(image.pixels[index + $0]) - background[$0]) > 34 }
    }
    func chooseCut(nominal: Int, tolerance: Int, maximum: Int, score: (Int) -> Int, threshold: Int) throws -> Int {
        let choices = max(2, nominal - tolerance)...min(maximum - 3, nominal + tolerance)
        var best = nominal, bestScore = Int.max
        for coordinate in choices {
            let value = score(coordinate - 1) + score(coordinate) + score(coordinate + 1)
            if value < bestScore || (value == bestScore && abs(coordinate - nominal) < abs(best - nominal)) {
                best = coordinate; bestScore = value
            }
        }
        guard bestScore <= max(6, threshold * 3) else {
            throw PreparationError("No clear gutter near \(nominal) (ink score \(bestScore)); provide reviewed --crops JSON rather than cutting through artwork.")
        }
        return best
    }
    var rows = [0]
    for boundary in 1..<rowCount {
        rows.append(try chooseCut(nominal: boundary * h / rowCount,
            tolerance: max(1, h / (rowCount * 4)), maximum: h,
            score: { y in (0..<w).reduce(0) { $0 + (occupied($1, y) ? 1 : 0) } }, threshold: w / 50))
    }
    rows.append(h)
    var result = [Bounds]()
    for row in 0..<rowCount {
        var columns = [0]
        for boundary in 1..<columnCount {
            let cut = try chooseCut(nominal: boundary * w / columnCount,
                tolerance: max(1, w / (columnCount * 4)),
                maximum: w, score: { x in (rows[row]..<rows[row + 1]).reduce(0) {
                    $0 + (occupied(x, $1) ? 1 : 0)
                } }, threshold: (rows[row + 1] - rows[row]) / 40)
            columns.append(cut)
        }
        columns.append(w)
        for column in 0..<columnCount {
            result.append(Bounds(left: columns[column], top: rows[row],
                right: columns[column + 1], bottom: rows[row + 1]))
        }
    }
    return result
}

@available(macOS 14.0, *)
func segment(_ image: CGImage, raster: inout Raster) throws -> Int {
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
        throw PreparationError("Vision found no foreground subject; review the measured crop.")
    }
    let mask = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
    guard CVPixelBufferGetWidth(mask) == raster.width && CVPixelBufferGetHeight(mask) == raster.height else {
        throw PreparationError("Vision mask dimensions do not match the source crop.")
    }
    let format = CVPixelBufferGetPixelFormatType(mask)
    guard format == kCVPixelFormatType_OneComponent32Float || format == kCVPixelFormatType_OneComponent8 else {
        throw PreparationError("Unsupported Vision alpha pixel format: \(format).")
    }
    CVPixelBufferLockBaseAddress(mask, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(mask) else { throw PreparationError("Cannot access Vision mask.") }
    let stride = CVPixelBufferGetBytesPerRow(mask)
    for y in 0..<raster.height {
        let row = base.advanced(by: y * stride)
        for x in 0..<raster.width {
            let amount: Double
            if format == kCVPixelFormatType_OneComponent32Float {
                let value = Double(row.assumingMemoryBound(to: Float.self)[x])
                amount = value.isFinite ? min(1, max(0, value)) : 0
            } else { amount = Double(row.assumingMemoryBound(to: UInt8.self)[x]) / 255 }
            let pixel = (y * raster.width + x) * 4
            let oldAlpha = Int(raster.pixels[pixel + 3])
            let alpha = Int((Double(oldAlpha) * amount).rounded())
            if oldAlpha == 0 || alpha < Int(alphaFloor) {
                raster.clear(y * raster.width + x)
            } else {
                // Change alpha while preserving the original unassociated RGB.
                // The bitmap is premultiplied, so RGB bytes must follow alpha.
                for channel in 0..<3 {
                    raster.pixels[pixel + channel] = UInt8((Int(raster.pixels[pixel + channel]) * alpha + oldAlpha / 2) / oldAlpha)
                }
                raster.pixels[pixel + 3] = UInt8(alpha)
            }
        }
    }
    return observation.allInstances.count
}

func validateSubject(_ raster: inout Raster, allowedEdges: Set<String>) throws -> (Bounds, Int, [[String: Any]], [String: Int]) {
    var components = raster.components()
    guard let primary = components.first, primary.pixels >= max(100, raster.width * raster.height / 500) else {
        throw PreparationError("Foreground is empty or implausibly small.")
    }
    // Remove only isolated speckles, not detached weapons, jewels, or horse legs.
    let dustLimit = max(8, primary.pixels / 10000)
    var removed = 0
    for component in components where component.pixels < dustLimit {
        for index in component.indices { raster.clear(index); removed += 1 }
    }
    components = components.filter { $0.pixels >= dustLimit }
    let minX = components.map(\.left).min()!, minY = components.map(\.top).min()!
    let maxX = components.map(\.right).max()!, maxY = components.map(\.bottom).max()!
    let combined = Bounds(left: minX, top: minY, right: maxX, bottom: maxY)
    guard combined.width >= 12 && combined.height >= 24 else {
        throw PreparationError("Foreground silhouette is too small to be a complete piece.")
    }
    var edgePixels = 0
    var edgeCounts = ["left": 0, "top": 0, "right": 0, "bottom": 0]
    for y in 0..<raster.height {
        for x in 0..<raster.width where x < 2 || y < 2 || x >= raster.width - 2 || y >= raster.height - 2 {
            guard raster.pixels[(y * raster.width + x) * 4 + 3] >= 64 else { continue }
            var contacts = [String]()
            if x < 2 { contacts.append("left") }
            if y < 2 { contacts.append("top") }
            if x >= raster.width - 2 { contacts.append("right") }
            if y >= raster.height - 2 { contacts.append("bottom") }
            for edge in contacts { edgeCounts[edge, default: 0] += 1 }
            if contacts.contains(where: { !allowedEdges.contains($0) }) { edgePixels += 1 }
        }
    }
    guard edgePixels <= max(10, primary.pixels / 300) else {
        let contacts = edgeCounts.keys.sorted().map { "\($0)=\(edgeCounts[$0]!)" }.joined(separator: ", ")
        throw PreparationError("Foreground touches an unreviewed crop edge (\(edgePixels) pixels; \(contacts)): likely a clipped piece or neighbouring image; adjust reviewed bounds.")
    }
    for component in components.dropFirst() where component.pixels > primary.pixels / 5 {
        let horizontalGap = max(primary.left, component.left) - min(primary.right, component.right)
        let verticalGap = max(primary.top, component.top) - min(primary.bottom, component.bottom)
        let twoStandingSubjects = component.bounds.height > primary.bounds.height / 2 && horizontalGap > 3
        let twoStackedSubjects = component.bounds.width > primary.bounds.width / 2 && verticalGap > 5
        guard !twoStandingSubjects && !twoStackedSubjects else {
            throw PreparationError("Multiple substantial separated silhouettes found (\(primary.pixels), \(component.pixels) pixels); inspect for a neighbouring piece before adjusting crops.")
        }
    }
    let report = components.map { ["bounds": $0.bounds.array, "pixels": $0.pixels] as [String: Any] }
    return (combined, removed, report, edgeCounts)
}

func writeReport(_ report: [String: Any], to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url, options: .atomic)
}

func prepare(_ options: Options) throws {
    guard let imageSource = CGImageSourceCreateWithURL(options.input as CFURL, nil),
          let source = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        throw PreparationError("Cannot decode \(options.input.path).")
    }
    guard source.width >= 192 && source.height >= 128 && source.width <= 16384 && source.height <= 16384 else {
        throw PreparationError("Unsupported source dimensions: \(source.width)×\(source.height).")
    }
    let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
    if let orientation = properties?[kCGImagePropertyOrientation] as? Int, orientation != 1 {
        throw PreparationError("Source has EXIF orientation \(orientation); normalize orientation before measuring crops.")
    }
    let original = try Raster(source)
    let bounds = try options.crops.map {
        try measuredBounds($0, source: source, count: options.columns * options.rows)
    } ?? automaticBounds(original, columnCount: options.columns, rowCount: options.rows)
    let allowedEdges = try reviewedEdgeContacts(options.crops, count: bounds.count)
    let exclusions = try reviewedExclusions(options.crops, source: source, crops: bounds)
    var overlappingPairs = [[Int]]()
    for first in 0..<bounds.count {
        for second in (first + 1)..<bounds.count where bounds[first].intersects(bounds[second]) {
            guard exclusions.allowOverlappingCrops else {
                throw PreparationError("Crop rectangles \(first) and \(second) overlap; use non-overlapping measured bounds or explicitly reviewed allowOverlappingCrops/excludedRects.")
            }
            guard exclusions.rectangles[first] != nil, exclusions.rectangles[second] != nil else {
                throw PreparationError("Reviewed overlapping crops \(first) and \(second) each require explicit excludedRects to isolate neighbouring artwork.")
            }
            overlappingPairs.append([first, second])
        }
    }
    let outputWidth = options.columns * 256, outputHeight = options.rows * 256, cellSize = 256
    let isArmy = options.columns == 6 && options.rows == 2
    guard let canvas = CGContext(data: nil, width: outputWidth, height: outputHeight,
        bitsPerComponent: 8, bytesPerRow: outputWidth * 4, space: sRGB, bitmapInfo: rgbaInfo) else {
        throw PreparationError("Cannot allocate final atlas.")
    }
    canvas.interpolationQuality = .high
    canvas.setShouldAntialias(true)
    var cells = [[String: Any]]()
    var report: [String: Any] = [
        "input": options.input.path, "output": options.output.path,
        "sourceSize": [source.width, source.height], "outputSize": [outputWidth, outputHeight],
        "order": isArmy ? roles + roles : bounds.indices.map { "sprite-\($0)" },
        "columns": options.columns, "rows": options.rows,
        "coordinateSystem": "top-left, exclusive right/bottom",
        "normalization": ["cellSize": cellSize, "maxWidth": 224, "maxHeight": 226, "baseline": 244],
        "alphaFloor": Int(alphaFloor), "cropMode": options.crops == nil ? "detected-gutters" : "measured",
        "bounds": bounds.map(\.array), "status": "processing",
        "allowOverlappingCrops": exclusions.allowOverlappingCrops,
        "reviewedOverlappingPairs": overlappingPairs,
        "excludedRects": Dictionary(uniqueKeysWithValues: exclusions.rectangles.map { (String($0.key), $0.value.map(\.array)) }),
        "reviewRequired": "Inspect full atlas and checkerboard previews; segmentation checks cannot prove anatomical or historical correctness."
    ]
    do {
        for (index, region) in bounds.enumerated() {
            let entry: [String: Any] = try autoreleasepool {
                guard let crop = source.cropping(to: region.rect) else { throw PreparationError("Cannot crop cell \(index).") }
                var raster = try Raster(crop)
                let preserveAlpha = raster.hasMeaningfulAlpha
                var instances = 0
                if !preserveAlpha {
                    if #available(macOS 14.0, *) { instances = try segment(crop, raster: &raster) }
                    else { throw PreparationError("Opaque source needs macOS14+ Vision foreground segmentation.") }
                }
                let cellExclusions = exclusions.rectangles[index] ?? []
                let excludedPixels = clearReviewedExclusions(cellExclusions, region: region, raster: &raster)
                let fringe = raster.cleanLowAlpha()
                let cellAllowedEdges = allowedEdges[index] ?? []
                let (alphaBounds, speckles, components, edgeCounts) = try validateSubject(&raster,
                    allowedEdges: cellAllowedEdges)
                let acceptedContacts = cellAllowedEdges.sorted().filter { edgeCounts[$0, default: 0] > 0 }
                let warnings = acceptedContacts.map {
                    "Reviewed \($0) crop contact accepted (\(edgeCounts[$0, default: 0]) pixels); verify intentional plinth trim in visual QA."
                }
                guard let trimmed = try raster.image().cropping(to: alphaBounds.rect) else {
                    throw PreparationError("Cannot trim alpha bounds for cell \(index).")
                }
                let scale = min(224.0 / Double(alphaBounds.width), 226.0 / Double(alphaBounds.height))
                let width = max(1, Int((Double(alphaBounds.width) * scale).rounded()))
                let height = max(1, Int((Double(alphaBounds.height) * scale).rounded()))
                let column = index % options.columns, row = index / options.columns
                let targetX = column * cellSize + (cellSize - width) / 2
                let targetY = row * cellSize + 244 - height
                canvas.saveGState()
                canvas.clip(to: CGRect(x: column * cellSize, y: outputHeight - (row + 1) * cellSize,
                    width: cellSize, height: cellSize))
                canvas.draw(trimmed, in: CGRect(x: targetX, y: outputHeight - targetY - height, width: width, height: height))
                canvas.restoreGState()
                return [
                    "index": index, "row": row, "column": column,
                    "side": isArmy ? (row == 0 ? "white" : "black") : "unspecified",
                    "role": isArmy ? roles[column] : "sprite-\(index)",
                    "sourceCrop": region.array, "localAlphaBounds": alphaBounds.array,
                    "sourceAlphaBounds": [region.left + alphaBounds.left, region.top + alphaBounds.top,
                        region.left + alphaBounds.right, region.top + alphaBounds.bottom],
                    "destinationBounds": [targetX, targetY, targetX + width, targetY + height],
                    "scale": scale, "maskMode": preserveAlpha ? "preserved-alpha" : "vision-alpha-only",
                    "visionInstances": instances, "removedFringePixels": fringe,
                    "removedSpecklePixels": speckles, "components": components,
                    "edgeContactPixels": edgeCounts,
                    "reviewedEdgeExceptions": cellAllowedEdges.sorted(),
                    "excludedRects": cellExclusions.map(\.array),
                    "removedExcludedPixels": excludedPixels,
                    "warnings": warnings,
                    "transparentFraction": Double(raster.transparentCount) / Double(raster.width * raster.height),
                    "validation": "passed"
                ]
            }
            cells.append(entry)
            let label = isArmy ? "\(index < 6 ? "white" : "black") \(roles[index % 6])" : "sprite-\(index)"
            print("Prepared \(index + 1)/\(bounds.count) \(label)")
            fflush(stdout)
        }
        guard let completed = canvas.makeImage() else { throw PreparationError("Cannot finish normalized atlas.") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw PreparationError("Cannot create PNG encoder.")
        }
        CGImageDestinationAddImage(destination, completed, nil)
        guard CGImageDestinationFinalize(destination) else { throw PreparationError("PNG encoding failed.") }
        try FileManager.default.createDirectory(at: options.output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (data as Data).write(to: options.output, options: .atomic)
        report["status"] = "passed"
        report["cells"] = cells
        try writeReport(report, to: options.report)
        print("Saved \(options.output.path) (\(outputWidth)×\(outputHeight)); report: \(options.report.path)")
    } catch {
        report["status"] = "failed"
        report["failedCell"] = cells.count
        report["error"] = String(describing: error)
        report["cells"] = cells
        try? writeReport(report, to: options.report)
        throw PreparationError("Cell \(cells.count): \(error). No unvalidated atlas was written. QA report: \(options.report.path)")
    }
}

do {
    try prepare(parseOptions())
} catch {
    FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
    exit(1)
}
