//
//  ContentView.swift
//  Disk Visualizer
//
//  Created by François Monniot on 7/19/26.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    /// Whether the user dismissed the incomplete-results banner for this scan.
    @State private var warningDismissed = false

    private var theme: Theme { colorScheme == .light ? .light : .dark }

    var body: some View {
        @Bindable var model = model
        content
            .environment(\.theme, theme)
            .foregroundStyle(theme.text)
            .frame(minWidth: 820, minHeight: 560)
            .navigationTitle(windowTitle)
            .fileImporter(
                isPresented: $model.isPresentingImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    model.scan(url: url)
                }
            }
    }

    private func chooseFolder() { model.isPresentingImporter = true }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .idle:
            WelcomeView(chooseFolder: chooseFolder)
                .environment(\.theme, theme)
        case .failed(let message):
            FailureView(message: message, chooseFolder: chooseFolder)
                .environment(\.theme, theme)
        case .scanning, .loaded:
            mainLayout
        }
    }

    private var mainLayout: some View {
        VStack(spacing: 0) {
            TopBarView()
            HStack(spacing: 0) {
                SidebarTreeView()
                ZStack {
                    VisualizationStageView()
                    if model.isScanning {
                        LoadingOverlayView(
                            name: model.scannedURL?.lastPathComponent ?? "…",
                            itemCount: model.scannedItemCount
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                DetailsPanelView()
            }
            BottomBarView(onChooseFolder: chooseFolder)
        }
        .background {
            GeometryReader { geo in
                theme.backgroundGradient(diameter: max(geo.size.width, geo.size.height) * 1.2)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(message: toast)
                    .padding(.bottom, 78)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if showIncompleteWarning {
                IncompleteResultsBanner(
                    count: model.unreadableDirectories,
                    onDismiss: { warningDismissed = true }
                )
                .padding(.top, 52)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: model.scannedURL) { warningDismissed = false }
        .animation(.easeOut(duration: 0.28), value: model.toast)
        .animation(.easeOut(duration: 0.28), value: showIncompleteWarning)
    }

    private var showIncompleteWarning: Bool {
        model.phase == .loaded && model.unreadableDirectories > 0 && !warningDismissed
    }

    private var windowTitle: String {
        if let name = model.root?.name { return "Disk Visualizer — \(name)" }
        return "Disk Visualizer"
    }
}

/// Shown before any scan.
private struct WelcomeView: View {
    @Environment(\.theme) private var theme
    var chooseFolder: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                theme.backgroundGradient(diameter: max(geo.size.width, geo.size.height) * 1.2)
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 46, weight: .regular))
                        .foregroundStyle(Color(hex: "8a7bff"))
                    Text("Disk Visualizer")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(theme.name)
                    Text("Choose a folder to scan and see how its space is used.")
                        .font(.callout)
                        .foregroundStyle(theme.muted2)
                    Button("Choose Folder…", action: chooseFolder)
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "6a4bff"))
                        .padding(.top, 4)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Shown after a scan that skipped protected/unreadable directories, warning
/// that the totals undercount. Dismissible.
private struct IncompleteResultsBanner: View {
    @Environment(\.theme) private var theme
    let count: Int
    var onDismiss: () -> Void

    private var headline: String {
        count == 1
            ? "1 folder couldn’t be read and was skipped"
            : "\(count.formatted()) folders couldn’t be read and were skipped"
    }

    private func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(headline)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.toastText)
                Text("Totals may be incomplete. Grant Disk Visualizer Full Disk Access, then scan again to include protected locations.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.muted2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Full Disk Access Settings…", action: openFullDiskAccessSettings)
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.muted2)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.toastBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.toastBorder)
        )
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }
}

private struct FailureView: View {
    @Environment(\.theme) private var theme
    let message: String
    var chooseFolder: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                theme.backgroundGradient(diameter: max(geo.size.width, geo.size.height) * 1.2)
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("Couldn't scan that folder")
                        .font(.headline)
                        .foregroundStyle(theme.name)
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(theme.muted2)
                        .multilineTextAlignment(.center)
                    Button("Choose Folder…", action: chooseFolder)
                        .padding(.top, 4)
                }
                .padding(40)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

#Preview {
    ContentView()
        .environment(VisualizerModel())
}
