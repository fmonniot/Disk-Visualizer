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
                case .sunburst:
                    SunburstView()
                case .treemap:
                    TreemapView()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
