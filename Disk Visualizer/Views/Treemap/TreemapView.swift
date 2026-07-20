//
//  TreemapView.swift
//  Disk Visualizer
//
//  Squarified treemap of the current folder's immediate children. Tiles are
//  sized by disk usage; hovering shows the shared tooltip.
//

import SwiftUI

struct TreemapView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme

    @State private var hoveredID: FileNode.ID?
    @State private var cursor: CGPoint = .zero
    @State private var tiles: [TreemapTile] = []

    var body: some View {
        GeometryReader { geo in
            let content = geo.size
            if let current = model.current {
                ZStack(alignment: .topLeading) {
                    // Tiles are clipped to the stage so they never bleed under
                    // the surrounding bars.
                    ZStack(alignment: .topLeading) {
                        if tiles.isEmpty {
                            EmptyFolderView()
                                .frame(width: content.width, height: content.height)
                        } else {
                            ForEach(tiles) { tile in
                                TreemapCell(
                                    tile: tile,
                                    isSelected: model.selection?.id == tile.id,
                                    isHovered: hoveredID == tile.id
                                )
                                .onHover { inside in
                                    if inside { hoveredID = tile.id }
                                    else if hoveredID == tile.id { hoveredID = nil }
                                }
                                .onTapGesture { model.activate(tile.node) }
                            }
                        }
                    }
                    .frame(width: content.width, height: content.height)
                    .clipped()

                    // Tooltip floats above and is not clipped.
                    if let id = hoveredID, let node = tiles.first(where: { $0.id == id })?.node {
                        FloatingTooltip(node: node, cursor: cursor, container: content)
                    }
                }
                .frame(width: content.width, height: content.height)
                .coordinateSpace(name: "treemap")
                .onContinuousHover(coordinateSpace: .named("treemap")) { phase in
                    if case .active(let location) = phase { cursor = location }
                }
                .animation(.easeInOut(duration: 0.2), value: current.id)
                .onChange(of: current.id, initial: true) {
                    tiles = Self.layoutTiles(current, content)
                }
                .onChange(of: content, initial: true) {
                    tiles = Self.layoutTiles(current, content)
                }
            }
        }
        .padding(24)
    }

    private static func layoutTiles(_ current: FileNode, _ content: CGSize) -> [TreemapTile] {
        TreemapLayout.tiles(for: current.children.filter { $0.size > 0 }, in: content)
    }
}

private struct TreemapCell: View {
    @Environment(\.theme) private var theme
    let tile: TreemapTile
    let isSelected: Bool
    let isHovered: Bool

    private var showLabel: Bool { tile.rect.width > 96 && tile.rect.height > 38 }

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(gradient)
            .overlay(alignment: .topLeading) { label }
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.gap, lineWidth: 1.5))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(theme.tileSel, lineWidth: 2)
                    .opacity(isSelected ? 1 : 0)
            )
            .brightness(isHovered ? 0.05 : 0)
            .frame(width: tile.rect.width, height: tile.rect.height)
            .offset(x: tile.rect.minX, y: tile.rect.minY)
            .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [tile.node.category.startColor, tile.node.category.endColor],
            startPoint: .top,
            endPoint: .bottomLeading
        )
    }

    @ViewBuilder private var label: some View {
        if showLabel {
            VStack(alignment: .leading, spacing: 1) {
                Text(tile.node.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(ByteFormat.string(tile.node.size))
                    .font(.system(size: 11, design: .monospaced))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: tile.rect.width, alignment: .leading)
        }
    }
}
