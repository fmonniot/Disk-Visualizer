//
//  SidebarTreeView.swift
//  Disk Visualizer
//
//  The left "Folder Structure" column: a disclosure tree of the scanned
//  hierarchy with per-type swatches and sizes.
//

import SwiftUI

struct SidebarTreeView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Folder Structure")
                .sectionHeader(theme)
                .padding(.top, 14)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if let root = model.root {
                        ForEach(visibleRows(from: root), id: \.node.id) { row in
                            TreeRow(node: row.node, depth: row.depth)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
        }
        .frame(width: 264)
        .background(theme.panel)
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.border).frame(width: 1)
        }
    }

    private struct Row {
        let node: FileNode
        let depth: Int
    }

    /// Flattens the tree into the currently-visible rows, honoring expansion.
    private func visibleRows(from root: FileNode) -> [Row] {
        var rows: [Row] = []
        func walk(_ node: FileNode, depth: Int) {
            rows.append(Row(node: node, depth: depth))
            guard !node.isLeaf, model.isEffectivelyExpanded(node) else { return }
            for child in node.children {
                walk(child, depth: depth + 1)
            }
        }
        walk(root, depth: 0)
        return rows
    }
}

private struct TreeRow: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme
    let node: FileNode
    let depth: Int

    @State private var hovering = false

    private var isSelected: Bool { model.selection?.id == node.id }
    private var isCurrent: Bool { model.current?.id == node.id }
    private var isSearchMatch: Bool { model.isSearchMatch(node) }
    private var isDimmed: Bool { model.isSearchDimmed(node) }

    private var background: Color {
        if isSelected { return theme.treeSel }
        if hovering { return theme.treeHover }
        if isCurrent { return theme.treeCur }
        return .clear
    }

    var body: some View {
        HStack(spacing: 6) {
            disclosure
            GradientSwatch(category: node.category, size: 9, cornerRadius: node.isLeaf ? nil : 3)
            Text(node.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .fontWeight(isSearchMatch ? .semibold : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(ByteFormat.string(node.size))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.treeSize)
        }
        .font(.system(size: 13))
        .foregroundStyle(isSelected ? theme.treeSelText : theme.treeText)
        .opacity(isDimmed ? 0.4 : 1)
        .frame(height: 27)
        .padding(.leading, CGFloat(depth * 13 + 8))
        .padding(.trailing, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { model.activate(node) }
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var disclosure: some View {
        if node.isLeaf {
            Color.clear.frame(width: 14)
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.disc)
                .rotationEffect(.degrees(model.isEffectivelyExpanded(node) ? 90 : 0))
                .frame(width: 14)
                .contentShape(Rectangle())
                .onTapGesture { model.toggleExpanded(node) }
        }
    }
}
