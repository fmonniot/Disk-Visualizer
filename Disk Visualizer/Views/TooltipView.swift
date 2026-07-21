//
//  TooltipView.swift
//  Disk Visualizer
//
//  Floating hover card used by the sunburst: name, size, and the node's share
//  of its parent.
//

import SwiftUI

struct TooltipView: View {
    @Environment(\.theme) private var theme
    let node: FileNode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                GradientSwatch(category: node.category, size: 9, cornerRadius: 3)
                Text(node.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.tipText)
                    .lineLimit(1)
            }
            HStack(spacing: 16) {
                Text(ByteFormat.string(node.size))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.tipVal)
                Spacer(minLength: 0)
                Text(percentText)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.tipSub)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(minWidth: 150, maxWidth: 250, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.thickMaterial)
                RoundedRectangle(cornerRadius: 12).fill(theme.tipBg.opacity(0.45))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.tipBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
    }

    private var percentText: String {
        guard node.parent != nil else { return "100%" }
        return String(format: "%.1f%% of parent", node.fractionOfParent * 100)
    }
}

/// A `TooltipView` positioned near the cursor but kept fully inside `container`
/// (flipping to the other side of the cursor near an edge). Because it stays in
/// the stage, it never overflows into — and get drawn under — neighboring panes.
struct FloatingTooltip: View {
    let node: FileNode
    let cursor: CGPoint
    let container: CGSize
    var gap: CGFloat = 16

    @State private var size: CGSize = .zero

    var body: some View {
        TooltipView(node: node)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(x: origin(cursor.x, size.width, container.width),
                    y: origin(cursor.y, size.height, container.height))
    }

    private func origin(_ cursorValue: CGFloat, _ length: CGFloat, _ limit: CGFloat) -> CGFloat {
        var value = cursorValue + gap
        if value + length > limit { value = cursorValue - gap - length } // flip
        return max(0, min(value, max(0, limit - length)))                // clamp
    }
}
