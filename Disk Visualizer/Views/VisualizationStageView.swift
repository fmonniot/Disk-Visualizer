//
//  VisualizationStageView.swift
//  Disk Visualizer
//
//  The center pane that hosts the active visualization. The Sunburst and
//  Treemap renderers are added in later commits; for now it frames the current
//  folder so the layout is complete.
//

import SwiftUI

struct VisualizationStageView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                theme.backgroundGradient(diameter: max(geo.size.width, geo.size.height) * 1.2)

                switch model.viewMode {
                case .sunburst, .treemap:
                    placeholder
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder private var placeholder: some View {
        if let current = model.current {
            VStack(spacing: 2) {
                Text(current.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.labelName)
                Text(ByteFormat.string(current.size))
                    .font(.system(size: 25, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.labelBig)
                Text("\(current.fileCount.formatted()) items")
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.labelSub)
            }
        }
    }
}
