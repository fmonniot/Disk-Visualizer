//
//  TopBarView.swift
//  Disk Visualizer
//
//  The bar beneath the window title: breadcrumbs on the left, a search pill
//  on the right. The search pill filters the sidebar tree and dims
//  non-matching arcs/tiles by name, across the whole scanned tree.
//

import SwiftUI

struct TopBarView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            BreadcrumbsView()
            Spacer(minLength: 12)

            searchPill
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.border).frame(height: 1) }
    }

    private var searchPill: some View {
        @Bindable var model = model
        return HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .opacity(0.7)
            TextField("Search", text: $model.searchQuery)
                .textFieldStyle(.plain)
            if model.isSearching {
                Button {
                    model.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .opacity(0.7)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(theme.searchText)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .frame(minWidth: 160, alignment: .leading)
        .background(theme.searchBg, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.searchBorder, lineWidth: 1))
    }
}
