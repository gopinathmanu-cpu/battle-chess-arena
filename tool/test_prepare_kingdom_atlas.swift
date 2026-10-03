#!/usr/bin/env swift
// SPDX-License-Identifier: GPL-3.0-or-later
// Focused, offline regression checks for reviewed atlas crop exclusions.
// swift -module-cache-path build/swift-module-cache tool/test_prepare_kingdom_atlas.swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum Failure: Error { case assertion(String) }
func check(_ condition: Bool, _ message: String) throws {
    if !condition { throw Failure.assertion(message) }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("build/kingdom-crop-regression-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let source = folder.appendingPathComponent("source.png")
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: 256, height: 128, bitsPerComponent: 8,
    bytesPerRow: 256 * 4, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(red: 1, green: 0.1, blue: 0.1, alpha: 1))
context.fill(CGRect(x: 40, y: 24, width: 60, height: 80))
context.setFillColor(CGColor(red: 0.1, green: 0.2, blue: 1, alpha: 1))
context.fill(CGRect(x: 140, y: 24, width: 70, height: 80))
let destination = CGImageDestinationCreateWithURL(source as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
try check(CGImageDestinationFinalize(destination), "Cannot write fixture")

func run(_ name: String, configuration: [String: Any]) throws -> (Int32, String, URL) {
    let config = folder.appendingPathComponent("\(name).json")
    let output = folder.appendingPathComponent("\(name).png")
    try JSONSerialization.data(withJSONObject: configuration).write(to: config)
    let process = Process(), pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = ["-module-cache-path", "build/swift-module-cache",
        "tool/prepare_kingdom_atlas.swift", source.path, output.path,
        "--crops", config.path, "--columns", "2", "--rows", "1"]
    process.currentDirectoryURL = root
    process.standardOutput = pipe; process.standardError = pipe
    try process.run()
    let bytes = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: bytes, as: UTF8.self), output)
}

let bounds = [[0, 0, 150, 128], [90, 0, 256, 128]]
var config: [String: Any] = ["sourceSize": [256, 128], "bounds": bounds]
let strict = try run("strict", configuration: config)
try check(strict.0 != 0 && strict.1.contains("overlap"), "Strict mode must reject overlapping crops")
try check(!FileManager.default.fileExists(atPath: strict.2.path), "Rejected crop must not create runtime image")
config["allowOverlappingCrops"] = true
let missing = try run("missing-exclusions", configuration: config)
try check(missing.0 != 0 && missing.1.contains("each require explicit excludedRects"),
    "Overlap opt-in must still require reviewed exclusions for both cells")
config["excludedRects"] = ["0": [[130, 0, 150, 128]], "1": [[90, 0, 110, 128]]]
let valid = try run("reviewed", configuration: config)
try check(valid.0 == 0, "Reviewed exclusions should pass: \(valid.1)")
let reportURL = valid.2.deletingPathExtension().appendingPathExtension("report.json")
let report = try JSONSerialization.jsonObject(with: Data(contentsOf: reportURL)) as! [String: Any]
try check(report["allowOverlappingCrops"] as? Bool == true, "Report must record overlap opt-in")
try check(report["reviewedOverlappingPairs"] as? [[Int]] == [[0, 1]], "Report must identify reviewed pairs")
let cells = report["cells"] as! [[String: Any]]
try check(cells.count == 2, "Both isolated subjects must be produced")
for cell in cells {
    try check(cell["maskMode"] as? String == "preserved-alpha", "Transparent fixtures must not invoke Vision")
    try check((cell["removedExcludedPixels"] as? Int ?? 0) > 0, "Report must count removed fragments")
    try check((cell["components"] as? [[String: Any]])?.count == 1, "Only intended connected subject should remain")
    try check((cell["excludedRects"] as? [[Int]])?.count == 1, "Per-cell provenance must preserve exact exclusion")
}
config["excludedRects"] = ["0": [[-1, 0, 150, 128]], "1": [[90, 0, 110, 128]]]
let invalid = try run("invalid-exclusion", configuration: config)
try check(invalid.0 != 0 && invalid.1.contains("outside the source"), "Out-of-bounds exclusions must fail")
print("Passed four crop-exclusion regressions; fixtures: \(folder.path)")
