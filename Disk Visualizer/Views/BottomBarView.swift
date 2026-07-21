//
//  BottomBarView.swift
//  Disk Visualizer
//
//  The footer bar: the color legend.
//

import SwiftUI

struct BottomBarView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            LegendView()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
        .background(theme.bottomBar)
        .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
    }
}

private struct LegendView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 18) {
            ForEach(FileCategory.legendOrder, id: \.self) { category in
                HStack(spacing: 7) {
                    GradientSwatch(category: category, size: 11, cornerRadius: 3.5)
                    Text(category.label)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.legend)
                        .fixedSize()
                }
            }
        }
        .fixedSize()
    }
}
