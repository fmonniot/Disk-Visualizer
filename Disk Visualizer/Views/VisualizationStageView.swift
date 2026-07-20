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

    var body: some View {
        // Transparent — the shared window background shows through.
        ZStack {
            switch model.viewMode {
            case .sunburst:
                SunburstView()
            case .treemap:
                TreemapView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
