#!/usr/bin/env swift
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Bounds {
  var minX = Int.max
  var minY = Int.max
  var maxX = Int.min
  var maxY = Int.min
  var pixels = 0

  mutating func include(x: Int, y: Int) {
    minX = min(minX, x)
    minY = min(minY, y)
    maxX = max(maxX, x)
    maxY = max(maxY, y)
    pixels += 1
  }

  var width: Int { maxX - minX + 1 }
  var height: Int { maxY - minY + 1 }
  var centerX: Double { Double(minX + maxX) / 2 }
  var centerY: Double { Double(minY + maxY) / 2 }
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

guard CommandLine.arguments.count == 3 else {
  fail("Usage: build_aligned_piece_atlas.swift INPUT.png OUTPUT.png")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = NSImage(contentsOf: inputURL),
      let sourceCG = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
else { fail("Could not decode \(inputURL.path)") }

let width = sourceCG.width
let height = sourceCG.height
guard width >= 900, height >= 1400 else {
  fail("Expected a portrait 6x8 generated atlas or 1536x2048 aligned atlas, received \(width)x\(height)")
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bytesPerPixel = 4
let bytesPerRow = width * bytesPerPixel
var sourcePixels = [UInt8](repeating: 0, count: height * bytesPerRow)
guard let sourceContext = CGContext(
  data: &sourcePixels,
  width: width,
  height: height,
  bitsPerComponent: 8,
  bytesPerRow: bytesPerRow,
  space: colorSpace,
  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fail("Could not create source bitmap context") }
sourceContext.draw(sourceCG, in: CGRect(x: 0, y: 0, width: width, height: height))

// Label only substantial opaque silhouettes. Low-alpha cast shadows and loose
// glow pixels intentionally stay out of the production sprites.
let alphaThreshold: UInt8 = 42
let columns: [Int] = width == 1536
  ? [0, 256, 512, 768, 1024, 1280, 1536]
  : width == 971
  ? [0, 180, 348, 504, 666, 818, 971]
  : (0...6).map { $0 * width / 6 }

let rows: [Int]
if height == 2048 {
  rows = [0, 256, 512, 768, 1024, 1280, 1536, 1792, 2048]
} else if height == 1620 {
  rows = [0, 198, 389, 578, 765, 944, 1120, 1278, 1427]
} else {
  // Image generators often return a 3:4 canvas whose visible sprite rows are
  // not exactly one eighth high. Detect eight substantial horizontal ink bands
  // and split at the middle of their transparent gaps.
  let occupied = (0..<height).map { y in
    var count = 0
    for x in 0..<width where sourcePixels[(y * width + x) * 4 + 3] >= alphaThreshold {
      count += 1
    }
    return count >= max(24, width / 45)
  }
  var bands = [(Int, Int)]()
  var start: Int?
  for y in 0..<height {
    if occupied[y], start == nil { start = y }
    if !occupied[y], let first = start {
      bands.append((first, y - 1))
      start = nil
    }
  }
  if let first = start { bands.append((first, height - 1)) }
  guard bands.count == 8 else {
    fail("Expected eight visible sprite rows, detected \(bands.count): \(bands)")
  }
  var detected = [0]
  for index in 0..<7 {
    detected.append((bands[index].1 + bands[index + 1].0) / 2)
  }
  detected.append(height)
  rows = detected
}

// The generated art occasionally crosses the nominal column boundaries. Find
// the transparent/least-opaque gutter independently for every row of a raw
// generated atlas. Production atlases already have exact 256 px cell cuts.
var rowCuts = [[Int]]()
for row in 0..<8 {
  var cuts = [0]
  for boundary in columns[1..<6] {
    let tolerance = width == 1536 ? 0 : 48
    let range = max(1, boundary - tolerance)...min(width - 2, boundary + tolerance)
    let cut = range.min { lhs, rhs in
      var lhsCount = 0
      var rhsCount = 0
      for y in rows[row]..<rows[row + 1] {
        if sourcePixels[(y * width + lhs) * 4 + 3] >= alphaThreshold { lhsCount += 1 }
        if sourcePixels[(y * width + rhs) * 4 + 3] >= alphaThreshold { rhsCount += 1 }
      }
      return lhsCount == rhsCount ? abs(lhs - boundary) < abs(rhs - boundary) : lhsCount < rhsCount
    }!
    cuts.append(cut)
  }
  cuts.append(width)
  rowCuts.append(cuts)
}

func owner(x: Int, y: Int) -> Int {
  guard y >= 0, y < rows[8] else { return -1 }
  guard let row = (0..<8).first(where: { y >= rows[$0] && y < rows[$0 + 1] }),
        let column = (0..<6).first(where: {
          x >= rowCuts[row][$0] && x < rowCuts[row][$0 + 1]
        })
  else { return -1 }
  return row * 6 + column
}

var labels = [Int32](repeating: -1, count: width * height)
var components = [Bounds]()
var componentOwners = [Int]()
var queue = [Int]()
queue.reserveCapacity(80_000)

for y in 0..<height {
  for x in 0..<width {
    let start = y * width + x
    let componentOwner = owner(x: x, y: y)
    if componentOwner < 0 || labels[start] != -1 ||
       sourcePixels[start * 4 + 3] < alphaThreshold { continue }
    let label = Int32(components.count)
    var bounds = Bounds()
    queue.removeAll(keepingCapacity: true)
    queue.append(start)
    labels[start] = label
    var head = 0
    while head < queue.count {
      let index = queue[head]
      head += 1
      let px = index % width
      let py = index / width
      bounds.include(x: px, y: py)
      for ny in max(0, py - 1)...min(height - 1, py + 1) {
        for nx in max(0, px - 1)...min(width - 1, px + 1) {
          let neighbor = ny * width + nx
          if labels[neighbor] == -1,
             owner(x: nx, y: ny) == componentOwner,
             sourcePixels[neighbor * 4 + 3] >= alphaThreshold {
            labels[neighbor] = label
            queue.append(neighbor)
          }
        }
      }
    }
    components.append(bounds)
    componentOwners.append(componentOwner)
  }
}

let substantialComponents = components.filter { $0.pixels > 500 }
guard substantialComponents.count >= 48 else {
  let largest = components.map(\.pixels).sorted(by: >).prefix(12)
  fail("Found only \(substantialComponents.count) substantial silhouettes; largest components: \(largest)")
}
let cell = 256
let outputWidth = 6 * cell
let outputHeight = 8 * cell
var outputPixels = [UInt8](repeating: 0, count: outputWidth * outputHeight * 4)
for row in 0..<8 {
  for column in 0..<6 {
    let candidates = components.indices.filter { index in
      componentOwners[index] == row * 6 + column && components[index].pixels > 500
    }
    guard let componentIndex = candidates.max(by: {
      components[$0].pixels < components[$1].pixels
    }) else { fail("No character silhouette found at row \(row), column \(column)") }
    let bounds = components[componentIndex]

    let scale = min(224.0 / Double(bounds.width), 226.0 / Double(bounds.height))
    let drawWidth = max(1, Int((Double(bounds.width) * scale).rounded()))
    let drawHeight = max(1, Int((Double(bounds.height) * scale).rounded()))
    let targetX = column * cell + (cell - drawWidth) / 2
    let targetY = row * cell + 244 - drawHeight

    for dy in 0..<drawHeight {
      let sourceY = min(bounds.maxY, bounds.minY + Int(Double(dy) / scale))
      for dx in 0..<drawWidth {
        let sourceX = min(bounds.maxX, bounds.minX + Int(Double(dx) / scale))
        let sourceIndex = sourceY * width + sourceX
        if labels[sourceIndex] != Int32(componentIndex) { continue }
        let destinationIndex = ((targetY + dy) * outputWidth + targetX + dx) * 4
        let inputIndex = sourceIndex * 4
        outputPixels[destinationIndex] = sourcePixels[inputIndex]
        outputPixels[destinationIndex + 1] = sourcePixels[inputIndex + 1]
        outputPixels[destinationIndex + 2] = sourcePixels[inputIndex + 2]
        outputPixels[destinationIndex + 3] = sourcePixels[inputIndex + 3]
      }
    }
  }
}

guard let outputContext = CGContext(
  data: &outputPixels,
  width: outputWidth,
  height: outputHeight,
  bitsPerComponent: 8,
  bytesPerRow: outputWidth * bytesPerPixel,
  space: colorSpace,
  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
), let outputCG = outputContext.makeImage(),
   let destination = CGImageDestinationCreateWithURL(
     outputURL as CFURL,
     UTType.png.identifier as CFString,
     1,
     nil
   )
else { fail("Could not create output image") }
CGImageDestinationAddImage(destination, outputCG, nil)
guard CGImageDestinationFinalize(destination) else {
  fail("Could not write \(outputURL.path)")
}
print("Wrote 48 isolated sprites to \(outputURL.path) (\(outputWidth)x\(outputHeight))")
