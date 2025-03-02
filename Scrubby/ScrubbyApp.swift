//
//  ScrubbyApp.swift
//  Scrubby
//
//  Created by Ryan Graves on 2/16/25.
//

import SwiftUI
import Sparkle

@main
struct ScrubbyApp: App {
    @State private var statusItem: NSStatusItem?
    @State private var isWindowOpen = false
    @State private var droppedFileURL: URL?
    
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        // If you want to start the updater manually, pass false to startingUpdater and call .startUpdater() later
        // This is where you can also pass an updater delegate if you need one
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 900)
        //        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
        Settings {
                UpdaterSettingsView(updater: updaterController.updater)
            }
    }
}

