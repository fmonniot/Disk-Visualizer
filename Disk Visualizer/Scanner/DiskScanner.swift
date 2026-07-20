//
//  DiskScanner.swift
//  Disk Visualizer
//
//  Walks a directory tree on a background task and builds a `FileNode` tree
//  with recursive sizes. Everything here is `nonisolated` so it never runs on
//  the main actor (the project defaults to `@MainActor` isolation).
//

import Foundation

nonisolated enum DiskScanner {
    struct Cancelled: Error {}

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
        .contentModificationDateKey, .nameKey,
    ]

    private static let resourceKeySet = Set(resourceKeys)

    /// Directory extensions we present as a single opaque item (their contents
    /// are summed for size but not exposed as navigable children).
    private static let opaqueExtensions: Set<String> = [
        "app", "photoslibrary", "xcassets", "framework", "bundle",
        "sketch", "dsym", "pkg", "mpkg", "rtfd", "scptd",
    ]

    /// Scans `url` recursively. Throws `Cancelled` if the surrounding task is
    /// cancelled; other filesystem errors (permissions, races) are skipped.
    static func scan(url: URL) throws -> FileNode {
        try buildNode(at: url, isRoot: true)
    }

    private static func checkCancellation() throws {
        if Task.isCancelled { throw Cancelled() }
    }

    private static func buildNode(at url: URL, isRoot: Bool = false) throws -> FileNode {
        try checkCancellation()

        let values = try? url.resourceValues(forKeys: resourceKeySet)
        let isDirectory = values?.isDirectory ?? false
        let isSymlink = values?.isSymbolicLink ?? false
        let isPackage = (values?.isPackage ?? false) || isOpaqueByExtension(url)
        let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        let ownModified = values?.contentModificationDate ?? Date()
        let rootURL = isRoot ? url : nil

        // Leaves: plain files, symlinks, and opaque package bundles.
        if !isDirectory || isSymlink || isPackage {
            let size = (isDirectory && !isSymlink) ? directorySize(url) : leafSize(values)
            let category = FileCategory.forFile(extension: url.pathExtension)
            return FileNode(
                name: name, rootURL: rootURL, isDirectory: isDirectory,
                size: size, modified: ownModified,
                category: category, fileCount: 1, children: []
            )
        }

        // A regular directory: recurse into its contents.
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: []
        )) ?? []

        var children: [FileNode] = []
        children.reserveCapacity(contents.count)
        var cancelled: Cancelled?
        autoreleasepool {
            for child in contents {
                do {
                    children.append(try buildNode(at: child))
                } catch is Cancelled {
                    cancelled = Cancelled()
                    break
                } catch {
                    // Skip entries we can't read (permissions, transient errors).
                }
            }
        }
        if let cancelled { throw cancelled }

        let size = children.reduce(0) { $0 + $1.size }
        let fileCount = children.reduce(0) { $0 + $1.fileCount }
        let modified = children.map(\.modified).max() ?? ownModified
        let category = dominantCategory(of: children) ?? .folder

        return FileNode(
            name: name, rootURL: rootURL, isDirectory: true,
            size: size, modified: modified,
            category: category, fileCount: fileCount, children: children
        )
    }

    private static func isOpaqueByExtension(_ url: URL) -> Bool {
        opaqueExtensions.contains(url.pathExtension.lowercased())
    }

    private static func leafSize(_ values: URLResourceValues?) -> Int64 {
        Int64(values?.totalFileAllocatedSize
            ?? values?.fileAllocatedSize
            ?? values?.fileSize
            ?? 0)
    }

    private static let directorySizeKeys: [URLResourceKey] = [
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
    ]
    private static let directorySizeKeySet = Set(directorySizeKeys)

    /// Sums allocated sizes of every regular file inside an opaque directory.
    private static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: directorySizeKeys,
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }
            autoreleasepool {
                let values = try? fileURL.resourceValues(forKeys: directorySizeKeySet)
                total += leafSize(values)
            }
        }
        return total
    }

    /// The category holding the most bytes among `children` — matching the
    /// design's `_dom` aggregation.
    private static func dominantCategory(of children: [FileNode]) -> FileCategory? {
        var totals: [FileCategory: Int64] = [:]
        for child in children {
            totals[child.category, default: 0] += child.size
        }
        return totals.max { $0.value < $1.value }?.key
    }
}
