//
//  Disk_VisualizerApp.swift
//  Disk Visualizer
//
//  Created by François Monniot on 7/19/26.
//

import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct Disk_VisualizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
