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
    @State private var showImporter = false

    var body: some View {
        Group {
            switch model.phase {
            case .idle:
                emptyState
            case .scanning:
                scanningState
            case .loaded:
                loadedState
            case .failed(let message):
                failureState(message)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.scan(url: url)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("Disk Visualizer")
                .font(.title2.weight(.semibold))
            Text("Choose a folder to scan and visualize how its space is used.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Choose Folder…") { showImporter = true }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var scanningState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Scanning \(model.scannedURL?.lastPathComponent ?? "…")")
                .font(.headline)
            Text("Indexing files and calculating sizes")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Cancel") { model.cancelScan() }
        }
        .padding()
    }

    private var loadedState: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let root = model.root {
                List([root], children: \.childrenOrNil) { node in
                    HStack {
                        Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                            .foregroundStyle(node.category.startColor)
                        Text(node.name)
                        Spacer()
                        Text(ByteFormat.string(node.size))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Choose Folder…") { showImporter = true }
            }
        }
    }

    private func failureState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.orange)
            Text("Couldn't scan that folder")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Choose Folder…") { showImporter = true }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environment(VisualizerModel())
}
