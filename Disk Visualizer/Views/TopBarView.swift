//
//  TopBarView.swift
//  Disk Visualizer
//
//  The bar beneath the window title: breadcrumbs on the left, a "Choose
//  Folder" action and a (decorative) search pill on the right.
//

import SwiftUI

struct TopBarView: View {
    @Environment(\.theme) private var theme
    var onChooseFolder: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            BreadcrumbsView()
            Spacer(minLength: 12)

            Button(action: onChooseFolder) {
                Label("Choose Folder", systemImage: "folder")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.crumb)

            searchPill
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.border).frame(height: 1) }
    }

    // Decorative for now; wiring up filtering is a later enhancement.
    private var searchPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .opacity(0.7)
            Text("Search")
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
