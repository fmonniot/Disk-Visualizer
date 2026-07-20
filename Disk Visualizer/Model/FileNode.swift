//
//  FileNode.swift
//  Disk Visualizer
//
//  One node of the scanned filesystem tree. Built entirely on a background
//  task by `DiskScanner`, then handed to the UI and never mutated again — so
//  it is safe to treat as `Sendable` even though `parent` is a stored pointer.
//

import Foundation

nonisolated final class FileNode: Identifiable, @unchecked Sendable {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
    let name: String
    let isDirectory: Bool

    /// Total size in bytes (recursive, for directories).
    let size: Int64
    /// Most recent modification date within this subtree.
    let modified: Date
    /// Type used for coloring. For a directory this is the dominant category of
    /// its contents (weighted by size); for a file it is derived from its extension.
    let category: FileCategory
    /// Number of leaf files contained (1 for a file).
    let fileCount: Int

    let children: [FileNode]
    weak var parent: FileNode?

    /// Absolute URL of the scan root. `nil` for every non-root node — their
    /// `url` is instead computed on demand by walking `parent` (see below),
    /// avoiding a per-node `URL`/`NSURL` allocation.
    private let rootURL: URL?

    init(
        name: String,
        rootURL: URL? = nil,
        isDirectory: Bool,
        size: Int64,
        modified: Date,
        category: FileCategory,
        fileCount: Int,
        children: [FileNode]
    ) {
        self.name = name
        self.rootURL = rootURL
        self.isDirectory = isDirectory
        self.size = size
        self.modified = modified
        self.category = category
        self.fileCount = fileCount
        self.children = children
        for child in children {
            child.parent = self
        }
    }

    /// Absolute filesystem URL, computed on demand by walking up to the root
    /// (which stores the real scanned URL) and appending path components.
    var url: URL {
        if let rootURL { return rootURL }
        guard let parent else { return URL(fileURLWithPath: name) }
        return parent.url.appendingPathComponent(name)
    }

    /// A node with no navigable children (a plain file or an opaque package).
    var isLeaf: Bool { children.isEmpty }

    /// Children for `OutlineGroup`/`List` disclosure: `nil` marks a leaf.
    var childrenOrNil: [FileNode]? { children.isEmpty ? nil : children }

    /// Fraction of the parent's size occupied by this node (0...1). Root is 1.
    var fractionOfParent: Double {
        guard let parent, parent.size > 0 else { return 1 }
        return Double(size) / Double(parent.size)
    }

    /// Path from the root volume down to (and including) this node.
    var ancestryChain: [FileNode] {
        var chain: [FileNode] = []
        var node: FileNode? = self
        while let current = node {
            chain.insert(current, at: 0)
            node = current.parent
        }
        return chain
    }
}
