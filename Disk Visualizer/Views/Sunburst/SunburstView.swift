//
//  SunburstView.swift
//  Disk Visualizer
//
//  Concentric ring chart of the current folder. Arcs are laid out in a fixed
//  720×720 space and scaled to fit; the center label and tooltip are drawn
//  unscaled so their text stays crisp.
//

import SwiftUI

struct SunburstView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme

    @State private var hoveredID: FileNode.ID?
    @State private var cursor: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / 720

            if let current = model.current {
                let arcs = SunburstLayout.arcs(for: current)

                ZStack {
                    if arcs.isEmpty {
                        EmptyFolderView()
                    } else {
                        arcLayer(arcs)
                            .frame(width: 720, height: 720)
                            .scaleEffect(scale)
                            .frame(width: side, height: side)
                            .id(current.id)
                            .transition(.scale(scale: 0.84).combined(with: .opacity))
                    }

                    centerLabel(current)
                        .frame(width: 150)
                        .position(x: side / 2, y: side / 2)

                    if let id = hoveredID, let node = arcs.first(where: { $0.id == id })?.node {
                        tooltip(node)
                    }
                }
                .frame(width: side, height: side)
                .coordinateSpace(name: "stage")
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .onContinuousHover(coordinateSpace: .named("stage")) { phase in
                    if case .active(let location) = phase { cursor = location }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: current.id)
            }
        }
        .padding(24)
    }

    // MARK: - Arcs

    private func arcLayer(_ arcs: [SunburstArc]) -> some View {
        ZStack {
            ForEach(arcs) { arc in
                arcShape(arc)
            }
            if let selected = arcs.first(where: { $0.id == model.selection?.id }) {
                sector(for: selected)
                    .stroke(theme.tileSel, lineWidth: 2)
                    .opacity(0.92)
                    .allowsHitTesting(false)
            }
            centerDisc()
        }
    }

    private func sector(for arc: SunburstArc) -> AnnularSector {
        let rIn = SunburstLayout.innerRadius + CGFloat(arc.depth - 1) * SunburstLayout.ringWidth + SunburstLayout.gap
        let rOut = SunburstLayout.innerRadius + CGFloat(arc.depth) * SunburstLayout.ringWidth - SunburstLayout.gap
        // Clamp a full-circle arc so it doesn't degenerate.
        var end = arc.endAngle
        if end - arc.startAngle > 2 * .pi - 0.002 { end = arc.startAngle + 2 * .pi - 0.002 }
        return AnnularSector(center: SunburstLayout.center, innerRadius: rIn,
                             outerRadius: rOut, startAngle: arc.startAngle, endAngle: end)
    }

    @ViewBuilder private func arcShape(_ arc: SunburstArc) -> some View {
        if arc.endAngle - arc.startAngle >= 0.004 {
            let isHovered = hoveredID == arc.id
            let dimmed = hoveredID != nil && !isHovered
            let shape = sector(for: arc)
            let offset = isHovered
                ? CGSize(width: sin(arc.midAngle) * 5, height: -cos(arc.midAngle) * 5)
                : .zero

            shape
                .fill(radialGradient(arc.node.category))
                .overlay(shape.stroke(theme.gap, lineWidth: 1.6))
                .opacity(dimmed ? 0.5 : 1)
                .offset(offset)
                .shadow(color: isHovered ? .white.opacity(0.3) : .clear, radius: isHovered ? 5 : 0)
                .contentShape(shape)
                .onHover { inside in
                    if inside { hoveredID = arc.id }
                    else if hoveredID == arc.id { hoveredID = nil }
                }
                .onTapGesture { model.activate(arc.node) }
                .animation(.easeOut(duration: 0.18), value: hoveredID)
        }
    }

    private func radialGradient(_ category: FileCategory) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [category.startColor, category.endColor]),
            center: .center,
            startRadius: 0,
            endRadius: SunburstLayout.totalRadius
        )
    }

    private func centerDisc() -> some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [theme.centerC0, theme.centerC1]),
                    center: .center, startRadius: 0, endRadius: SunburstLayout.innerRadius - 6
                )
            )
            .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
            .frame(width: (SunburstLayout.innerRadius - 6) * 2, height: (SunburstLayout.innerRadius - 6) * 2)
            .position(SunburstLayout.center)
            .allowsHitTesting(false)
    }

    // MARK: - Center label

    private func centerLabel(_ current: FileNode) -> some View {
        let canGoUp = current.parent != nil
        return VStack(spacing: 2) {
            if canGoUp {
                HStack(spacing: 3) {
                    Text("‹").font(.system(size: 15))
                    Text("Back").font(.system(size: 12))
                }
                .foregroundStyle(theme.labelBack)
            }
            Text(current.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.labelName)
                .lineLimit(1)
                .frame(maxWidth: 142)
            Text(ByteFormat.string(current.size))
                .font(.system(size: 25, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.labelBig)
            Text("\(current.fileCount.formatted()) items")
                .font(.system(size: 11.5))
                .foregroundStyle(theme.labelSub)
        }
        .contentShape(Rectangle())
        .onTapGesture { if canGoUp { model.goToParent() } }
    }

    // MARK: - Tooltip

    private func tooltip(_ node: FileNode) -> some View {
        TooltipView(node: node)
            .fixedSize()
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(x: cursor.x + 16, y: cursor.y + 16)
    }
}

struct EmptyFolderView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .foregroundStyle(theme.emptyBorder)
                .frame(width: 60, height: 60)
            Text("This folder is empty")
                .font(.system(size: 14))
                .foregroundStyle(theme.emptyText)
        }
    }
}
