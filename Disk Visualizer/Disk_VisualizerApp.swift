//
//  Disk_VisualizerApp.swift
//  Disk Visualizer
//
//  Created by François Monniot on 7/19/26.
//

import SwiftUI

@main
struct Disk_VisualizerApp: App {
    @State private var model = VisualizerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 960, height: 620)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") { model.isPresentingImporter = true }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
