//
//  RevealInFinder.swift
//  Disk Visualizer
//

import AppKit

enum RevealInFinder {
    /// Selects the given item in Finder.
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
