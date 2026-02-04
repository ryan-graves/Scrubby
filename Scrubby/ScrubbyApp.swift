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
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 900)
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

