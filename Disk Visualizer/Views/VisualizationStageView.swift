//
//  VisualizationStageView.swift
//  Disk Visualizer
//
//  The center pane that hosts the sunburst visualization.
//

import SwiftUI

struct VisualizationStageView: View {
    var body: some View {
        // Transparent — the shared window background shows through.
        SunburstView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
