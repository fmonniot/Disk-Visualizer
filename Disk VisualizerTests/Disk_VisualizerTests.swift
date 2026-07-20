//
//  Disk_VisualizerTests.swift
//  Disk VisualizerTests
//
//  Created by François Monniot on 7/19/26.
//

import Testing
import Foundation
import CoreGraphics
@testable import Disk_Visualizer

struct Disk_VisualizerTests {

    // MARK: - Byte formatting (mirrors the design's fmt()).

    @Test func byteFormatting() {
        #expect(ByteFormat.string(500) == "500 B")
        #expect(ByteFormat.string(12 * 1024) == "12 KB")
        #expect(ByteFormat.string(480 * 1_048_576) == "480 MB")
        // Under 10 GB keeps one decimal.
        #expect(ByteFormat.string(Int64(8.9 * 1_073_741_824)) == "8.9 GB")
        // 10 GB and up drops decimals.
        #expect(ByteFormat.string(Int64(14.8 * 1_073_741_824)) == "15 GB")
        #expect(ByteFormat.string(Int64(2 * 1_099_511_627_776)) == "2.00 TB")
    }

    // MARK: - Category classification.

    @Test func categoryClassification() {
        #expect(FileCategory.forFile(extension: "mov") == .video)
        #expect(FileCategory.forFile(extension: "PNG") == .image)
        #expect(FileCategory.forFile(extension: "pdf") == .document)
        #expect(FileCategory.forFile(extension: "zip") == .archive)
        #expect(FileCategory.forFile(extension: "app") == .app)
        #expect(FileCategory.forFile(extension: "flac") == .audio)
        #expect(FileCategory.forFile(extension: "swift") == .code)
        #expect(FileCategory.forFile(extension: "unknownext") == .system)
    }

    // MARK: - Scanner against a real temporary tree.

    @Test func scannerAggregatesSizesAndCounts() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("dv-test-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let sub = root.appendingPathComponent("movies", isDirectory: true)
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)

        try Data(count: 4096).write(to: root.appendingPathComponent("a.pdf"))
        try Data(count: 8192).write(to: sub.appendingPathComponent("b.mov"))
        try Data(count: 4096).write(to: sub.appendingPathComponent("c.mov"))

        let tree = try DiskScanner.scan(url: root)

        #expect(tree.isDirectory)
        #expect(tree.fileCount == 3)
        #expect(tree.children.count == 2) // a.pdf + movies/
        // Aggregated size equals the sum of the children's sizes.
        #expect(tree.size == tree.children.reduce(0) { $0 + $1.size })

        let movies = try #require(tree.children.first { $0.name == "movies" })
        #expect(movies.fileCount == 2)
        #expect(movies.category == .video) // dominated by .mov files
    }

    // MARK: - Sunburst layout.

    @Test func sunburstArcsSpanFullCircle() {
        let root = Self.folder("root", children: [
            Self.file("big", .video, 800),
            Self.file("small", .image, 200),
        ])
        let arcs = SunburstLayout.arcs(for: root)
        let firstRing = arcs.filter { $0.depth == 1 }
        #expect(firstRing.count == 2)

        let span = firstRing.reduce(0.0) { $0 + ($1.endAngle - $1.startAngle) }
        #expect(abs(span - 2 * .pi) < 0.0001)

        // Proportional: the 800-byte child takes 80% of the circle.
        let big = try? #require(firstRing.first { $0.node.name == "big" })
        if let big {
            #expect(abs((big.endAngle - big.startAngle) - 2 * .pi * 0.8) < 0.0001)
        }
    }

    @MainActor
    @Test func sunburstHitTestingFindsArcUnderCursor() {
        let root = Self.folder("root", children: [
            Self.file("big", .video, 800),   // spans angle 0 ..< 0.8·2π from the top
            Self.file("small", .image, 200),
        ])
        let arcs = SunburstLayout.arcs(for: root)

        // A point straight up, in the first ring, lands in "big".
        let r = SunburstLayout.innerRadius + SunburstLayout.ringWidth / 2
        let top = CGPoint(x: SunburstLayout.center.x, y: SunburstLayout.center.y - r)
        #expect(SunburstView.arc(at: top, scale: 1, in: arcs)?.node.name == "big")

        // The center (inside the inner radius) matches no arc.
        #expect(SunburstView.arc(at: SunburstLayout.center, scale: 1, in: arcs) == nil)

        // Beyond the outermost ring matches no arc.
        let far = CGPoint(x: SunburstLayout.center.x, y: 0)
        #expect(SunburstView.arc(at: far, scale: 1, in: arcs) == nil)
    }

    // MARK: - Treemap layout.

    @Test func treemapTilesCoverArea() {
        let children = [
            Self.file("a", .video, 500),
            Self.file("b", .image, 300),
            Self.file("c", .document, 200),
        ]
        let size = CGSize(width: 1000, height: 620)
        let tiles = TreemapLayout.tiles(for: children, in: size)

        #expect(tiles.count == 3)
        let covered = tiles.reduce(0.0) { $0 + Double($1.rect.width * $1.rect.height) }
        #expect(abs(covered - Double(size.width * size.height)) < 1.0)

        // Largest node yields the largest tile.
        let largest = tiles.max { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }
        #expect(largest?.node.name == "a")
    }

    // MARK: - Helpers

    static func file(_ name: String, _ category: FileCategory, _ size: Int64) -> FileNode {
        FileNode(name: name,
                 isDirectory: false, size: size, modified: Date(),
                 category: category, fileCount: 1, children: [])
    }

    static func folder(_ name: String, children: [FileNode]) -> FileNode {
        let size = children.reduce(0) { $0 + $1.size }
        return FileNode(name: name,
                        isDirectory: true, size: size, modified: Date(),
                        category: .folder, fileCount: children.count, children: children)
    }
}
