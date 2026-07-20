//
//  BreadcrumbsView.swift
//  Disk Visualizer
//
//  The path from the scanned root down to the current focus, shown in the bar
//  under the title. Each crumb navigates.
//

import SwiftUI

struct BreadcrumbsView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        if let current = model.current {
            let chain = current.ancestryChain
            HStack(spacing: 4) {
                ForEach(Array(chain.enumerated()), id: \.element.id) { index, node in
                    Crumb(node: node, isLast: index == chain.count - 1)
                    if index < chain.count - 1 {
                        Text("›")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.crumbSep)
                            .padding(.horizontal, 1)
                    }
                }
            }
        }
    }
}

private struct Crumb: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme
    let node: FileNode
    let isLast: Bool

    @State private var hovering = false

    var body: some View {
        Text(node.name)
            .font(.system(size: 13, weight: isLast ? .semibold : .medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .contentShape(Rectangle())
            .onTapGesture { if !isLast { model.enter(node) } }
            .onHover { hovering = $0 }
    }

    private var color: Color {
        if isLast { return theme.crumbLast }
        return hovering ? theme.crumbHover : theme.crumb
    }
}
