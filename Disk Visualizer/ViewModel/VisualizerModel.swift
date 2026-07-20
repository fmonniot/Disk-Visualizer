//
//  VisualizerModel.swift
//  Disk Visualizer
//
//  Owns the scan lifecycle and all navigation state (current focus, selection,
//  expanded folders, active visualization). The view layer reads from here.
//

import Foundation
import Observation

@MainActor
@Observable
final class VisualizerModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case loaded
        case failed(String)
    }

    enum ViewMode: String, CaseIterable {
        case sunburst = "Sunburst"
        case treemap = "Treemap"
    }

    private(set) var phase: Phase = .idle

    /// Root of the scanned tree (the folder the user picked).
    private(set) var root: FileNode?
    /// The node currently framed by the visualization / breadcrumbs.
    private(set) var current: FileNode?
    /// The node whose details are shown on the right.
    private(set) var selection: FileNode?
    /// Folders expanded in the sidebar tree.
    private(set) var expanded: Set<FileNode.ID> = []

    var viewMode: ViewMode = .sunburst
    private(set) var scannedURL: URL?

    /// Drives the folder importer sheet (toggled by the toolbar and ⌘O).
    var isPresentingImporter = false
    /// Transient confirmation message shown as a toast.
    private(set) var toast: String?

    private var scanTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    var isScanning: Bool { phase == .scanning }

    // MARK: - Scanning

    func scan(url: URL) {
        scanTask?.cancel()
        scannedURL = url
        phase = .scanning
        root = nil
        current = nil
        selection = nil
        expanded = []

        scanTask = Task {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }

            let result: Result<FileNode, Error> = await Task.detached(priority: .userInitiated) {
                do { return .success(try DiskScanner.scan(url: url)) }
                catch { return .failure(error) }
            }.value

            if Task.isCancelled { return }

            switch result {
            case .success(let tree):
                apply(tree)
            case .failure(is DiskScanner.Cancelled):
                return
            case .failure(let error):
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        if phase == .scanning { phase = .idle }
    }

    private func apply(_ tree: FileNode) {
        root = tree
        current = tree
        selection = tree
        expanded = initialExpansion(for: tree)
        phase = .loaded
    }

    /// Expand the root and folders down to depth 2, matching the design.
    private func initialExpansion(for root: FileNode) -> Set<FileNode.ID> {
        var ids: Set<FileNode.ID> = []
        func walk(_ node: FileNode, depth: Int) {
            guard !node.isLeaf else { return }
            if depth <= 2 { ids.insert(node.id) }
            for child in node.children { walk(child, depth: depth + 1) }
        }
        walk(root, depth: 0)
        return ids
    }

    // MARK: - Navigation

    /// Frame a node: focus it, select it, and reveal it in the tree.
    func enter(_ node: FileNode) {
        current = node
        selection = node
        for ancestor in node.ancestryChain {
            if !ancestor.isLeaf { expanded.insert(ancestor.id) }
        }
    }

    /// Select a node for the details panel without changing focus.
    func select(_ node: FileNode) {
        selection = node
    }

    /// Clicking a segment/tile/tree row: drill into folders, select files.
    func activate(_ node: FileNode) {
        if node.isLeaf {
            select(node)
        } else {
            enter(node)
        }
    }

    /// Move focus up to the parent of the current node (the sunburst center).
    func goToParent() {
        if let parent = current?.parent {
            enter(parent)
        }
    }

    // MARK: - Actions

    /// Reveals a node in Finder and shows a confirmation toast.
    func reveal(_ node: FileNode) {
        RevealInFinder.reveal(node.url)
        showToast("Revealing “\(node.name)” in Finder")
    }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            if !Task.isCancelled { toast = nil }
        }
    }

    func toggleExpanded(_ node: FileNode) {
        guard !node.isLeaf else { return }
        if expanded.contains(node.id) {
            expanded.remove(node.id)
        } else {
            expanded.insert(node.id)
        }
    }

    func isExpanded(_ node: FileNode) -> Bool {
        expanded.contains(node.id)
    }
}
