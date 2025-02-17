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
                .frame(minWidth: 300, idealWidth: 300, minHeight: 200, idealHeight: 200)
                .navigationTitle("Scrubby")
                .background(Color.clear)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

