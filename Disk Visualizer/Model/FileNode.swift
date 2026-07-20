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
    let id = UUID()
    let name: String
    let url: URL
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

    init(
        name: String,
        url: URL,
        isDirectory: Bool,
        size: Int64,
        modified: Date,
        category: FileCategory,
        fileCount: Int,
        children: [FileNode]
    ) {
        self.name = name
        self.url = url
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
