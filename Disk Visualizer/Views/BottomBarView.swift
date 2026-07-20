//
//  BottomBarView.swift
//  Disk Visualizer
//
//  The footer bar: the color legend on the left and the Sunburst/Treemap
//  view toggle on the right.
//

import SwiftUI

struct BottomBarView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            LegendView()
            Spacer(minLength: 12)
            ViewToggle()
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
        .background(theme.bottomBar)
        .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
    }
}

private struct LegendView: View {
    @Environment(\.theme) private var theme

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 18, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
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
        .frame(maxWidth: 520, alignment: .leading)
    }
}

private struct ViewToggle: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(VisualizerModel.ViewMode.allCases, id: \.self) { mode in
                let active = model.viewMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { model.viewMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(active ? theme.toggleActiveText : theme.toggleText)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 6)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 7).fill(theme.toggleActiveBg)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(theme.searchBg, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(theme.searchBorder, lineWidth: 1))
    }
}
