//
//  SunburstView.swift
//  Disk Visualizer
//
//  Concentric ring chart of the current folder. Arcs are laid out in a fixed
//  720×720 space and scaled to fit. Hit-testing is analytic (cursor → radius →
//  depth, angle → segment) so the highlight, tooltip node, and tooltip position
//  always agree; the center label is scaled to match the disc so its text never
//  spills onto the rings.
//

import SwiftUI

struct SunburstView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme

    @State private var hoveredID: FileNode.ID?
    @State private var cursor: CGPoint = .zero
    @State private var arcs: [SunburstArc] = []

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / 720

            if let current = model.current {
                ZStack {
                    if arcs.isEmpty {
                        EmptyFolderView()
                    } else {
                        arcLayer(arcs)
                            .frame(width: 720, height: 720)
                            .scaleEffect(scale)
                            .frame(width: side, height: side)
                            .allowsHitTesting(false)
                            .id(current.id)
                            .transition(.scale(scale: 0.84).combined(with: .opacity))
                    }

                    centerLabel(current, scale: scale)
                        .position(x: side / 2, y: side / 2)

                    if let id = hoveredID, let node = arcs.first(where: { $0.id == id })?.node {
                        FloatingTooltip(node: node, cursor: cursor,
                                        container: CGSize(width: side, height: side))
                    }
                }
                .frame(width: side, height: side)
                .contentShape(Rectangle())
                .coordinateSpace(name: "stage")
                .onContinuousHover(coordinateSpace: .named("stage")) { phase in
                    switch phase {
                    case .active(let location):
                        cursor = location
                        hoveredID = Self.arc(at: location, scale: scale, in: arcs)?.id
                    case .ended:
                        hoveredID = nil
                    }
                }
                .gesture(
                    SpatialTapGesture(coordinateSpace: .named("stage"))
                        .onEnded { value in
                            handleTap(at: value.location, scale: scale, arcs: arcs, current: current)
                        }
                )
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: current.id)
            }
        }
        .padding(24)
        .onChange(of: model.current?.id, initial: true) {
            arcs = model.current.map(SunburstLayout.arcs(for:)) ?? []
        }
    }

    // MARK: - Analytic hit testing

    /// The arc under `point` (in the scaled "stage" space), or nil for the
    /// center / outside the rings.
    static func arc(at point: CGPoint, scale: CGFloat, in arcs: [SunburstArc]) -> SunburstArc? {
        guard scale > 0 else { return nil }
        let x = point.x / scale - SunburstLayout.center.x
        let y = point.y / scale - SunburstLayout.center.y
        let r = hypot(x, y)
        let r0 = SunburstLayout.innerRadius
        let rw = SunburstLayout.ringWidth
        guard r >= r0, r <= r0 + CGFloat(SunburstLayout.maxDepth) * rw else { return nil }

        let depth = min(SunburstLayout.maxDepth, Int((r - r0) / rw) + 1)
        var angle = atan2(Double(x), Double(-y)) // from top (12 o'clock), clockwise
        if angle < 0 { angle += 2 * .pi }

        return arcs.first {
            $0.depth == depth && angle >= $0.startAngle && angle < $0.endAngle
        }
    }

    private func handleTap(at point: CGPoint, scale: CGFloat, arcs: [SunburstArc], current: FileNode) {
        guard scale > 0 else { return }
        let x = point.x / scale - SunburstLayout.center.x
        let y = point.y / scale - SunburstLayout.center.y
        if hypot(x, y) < SunburstLayout.innerRadius {
            if current.parent != nil { model.goToParent() }
            return
        }
        if let arc = Self.arc(at: point, scale: scale, in: arcs) {
            model.activate(arc.node)
        }
    }

    // MARK: - Arcs (pure rendering)

    private func arcLayer(_ arcs: [SunburstArc]) -> some View {
        // Arcs thinner than this are invisible (see `arcShape`); drop them
        // before `ForEach` so they aren't diffed on every hover update.
        let visible = arcs.filter { $0.endAngle - $0.startAngle >= 0.004 }
        return ZStack {
            ForEach(visible) { arc in
                arcShape(arc)
            }
            if let selected = arcs.first(where: { $0.id == model.selection?.id }) {
                sector(for: selected)
                    .stroke(theme.tileSel, lineWidth: 2)
                    .opacity(0.92)
            }
            centerDisc()
        }
    }

    private func sector(for arc: SunburstArc) -> AnnularSector {
        let rIn = SunburstLayout.innerRadius + CGFloat(arc.depth - 1) * SunburstLayout.ringWidth + SunburstLayout.gap
        let rOut = SunburstLayout.innerRadius + CGFloat(arc.depth) * SunburstLayout.ringWidth - SunburstLayout.gap
        var end = arc.endAngle
        if end - arc.startAngle > 2 * .pi - 0.002 { end = arc.startAngle + 2 * .pi - 0.002 }
        return AnnularSector(center: SunburstLayout.center, innerRadius: rIn,
                             outerRadius: rOut, startAngle: arc.startAngle, endAngle: end)
    }

    private func arcShape(_ arc: SunburstArc) -> some View {
        let isHovered = hoveredID == arc.id
        let dimmed = (hoveredID != nil && !isHovered) || model.isSearchDimmed(arc.node)
        let shape = sector(for: arc)
        let offset = isHovered
            ? CGSize(width: sin(arc.midAngle) * 5, height: -cos(arc.midAngle) * 5)
            : .zero

        return shape
            .fill(radialGradient(arc.node.category))
            .overlay(shape.stroke(theme.gap, lineWidth: 1.6))
            .opacity(dimmed ? 0.5 : 1)
            .offset(offset)
            .shadow(color: isHovered ? .white.opacity(0.3) : .clear, radius: isHovered ? 5 : 0)
            .animation(.easeOut(duration: 0.18), value: hoveredID)
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
    }

    // MARK: - Center label (scaled to match the disc)

    private func centerLabel(_ current: FileNode, scale: CGFloat) -> some View {
        let s = max(scale, 0.1)
        let canGoUp = current.parent != nil
        return VStack(spacing: 2 * s) {
            if canGoUp {
                HStack(spacing: 3 * s) {
                    Text("‹").font(.system(size: 15 * s))
                    Text("Back").font(.system(size: 12 * s))
                }
                .foregroundStyle(theme.labelBack)
            }
            Text(current.name)
                .font(.system(size: 13 * s, weight: .medium))
                .foregroundStyle(theme.labelName)
                .lineLimit(1)
                .frame(maxWidth: 142 * s)
            Text(ByteFormat.string(current.size))
                .font(.system(size: 25 * s, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.labelBig)
            Text("\(current.fileCount.formatted()) items")
                .font(.system(size: 11.5 * s))
                .foregroundStyle(theme.labelSub)
        }
        .frame(width: 150 * s)
        .allowsHitTesting(false)
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
