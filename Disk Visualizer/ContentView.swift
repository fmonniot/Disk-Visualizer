//
//  ContentView.swift
//  Disk Visualizer
//
//  Created by François Monniot on 7/19/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

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
            TopBarView(onChooseFolder: chooseFolder)
            HStack(spacing: 0) {
                SidebarTreeView()
                ZStack {
                    VisualizationStageView()
                    if model.isScanning {
                        LoadingOverlayView(name: model.scannedURL?.lastPathComponent ?? "…")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                DetailsPanelView()
            }
            BottomBarView()
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
        .animation(.easeOut(duration: 0.28), value: model.toast)
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
