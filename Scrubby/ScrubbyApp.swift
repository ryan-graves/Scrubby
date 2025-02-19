//
//  ScrubbyApp.swift
//  Scrubby
//
//  Created by Ryan Graves on 2/16/25.
//

import SwiftUI

@main
struct ScrubbyApp: App {
    @State private var statusItem: NSStatusItem?
    @State private var isWindowOpen = false
    @State private var droppedFileURL: URL?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 900)
//        .windowStyle(.hiddenTitleBar)
    }
}

