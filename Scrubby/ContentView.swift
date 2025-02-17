//
//  ContentView.swift
//  Scrubby
//
//  Created by Ryan Graves on 2/16/25.
//

import SwiftUI

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedFileURL: URL?
    @State private var formattedFileName: String = ""
    @State private var selectedFormat: FormattingOption = .hyphenated
    @State private var isFileDropped: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage: Bool = false
    @State private var showFileImporter: Bool = false
    
    var body: some View {
        VStack {
            Text("Drop a file anywhere in this window to rename it")
                .font(.title2.bold())
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
                .multilineTextAlignment(.center)
            
            if isFileDropped {
                VStack(spacing: 16) {
                    Text("Selected File: **\(selectedFileURL?.lastPathComponent ?? "None")**")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Picker("Rename Format", selection: $selectedFormat) {
                        Text("Lowercase").tag(FormattingOption.lowercased)
                        Text("Camel Case").tag(FormattingOption.camelCased)
                        Text("Hyphenated").tag(FormattingOption.hyphenated)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedFormat) { _ in
                        applySelectedFormatting()
                    }
                    
                    Text("New Name: **\(formattedFileName)**")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Button("Rename File", systemImage: "pencil") {
                        renameFile()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(formattedFileName.isEmpty)
                }
                .padding()
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Makes the whole window interactive
        .contentShape(Rectangle()) // Ensures drag interaction anywhere
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
        .overlay(
            Group {
                if showSuccessMessage {
                    Text("✅ File renamed successfully!")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.secondary.opacity(0.7))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        .transition(.opacity)
                        .zIndex(1)
                        .padding(32)
                }
            }, alignment: .bottom
        )
    }
    
    /// Handles file drop anywhere in the window
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        if let item = providers.first {
            item.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, error) in
                if let data = data as? Data,
                   let fileURL = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        selectedFileURL = fileURL
                        isFileDropped = true
                        formattedFileName = applySelectedFormatting(for: fileURL, format: selectedFormat)
                        
                        // Store both file & folder access for sandboxed environments
                        storeFileBookmark(for: fileURL)
                    }
                }
            }
            return true
        }
        return false
    }
    
    /// Applies the selected formatting to the filename
    /// Applies the selected formatting to the filename (Used inside the view)
    private func applySelectedFormatting() {
        guard let fileURL = selectedFileURL else { return }
        formattedFileName = applySelectedFormatting(for: fileURL, format: selectedFormat) // Uses argument-based function
    }
    
    /// Applies the selected formatting (Used when a file is dropped)
    private func applySelectedFormatting(for fileURL: URL, format: FormattingOption) -> String {
        let fileNameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
        
        return {
            switch selectedFormat {
            case .lowercased: return fileNameWithoutExtension.cleanLowercased()
            case .camelCased: return fileNameWithoutExtension.camelCased()
            case .hyphenated: return fileNameWithoutExtension.hyphenated()
            }
        }() + (fileURL.pathExtension.isEmpty ? "" : ".\(fileURL.pathExtension)")
    }
    
    /// Stores security-scoped bookmarks for both file and folder
    private func storeFileBookmark(for fileURL: URL) {
        let folderURL = fileURL.deletingLastPathComponent() // Get parent folder
        
        do {
            // Store file bookmark
            let fileBookmarkData = try fileURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(fileBookmarkData, forKey: "savedFileBookmark")
            
            // Store folder bookmark
            let folderBookmarkData = try folderURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(folderBookmarkData, forKey: "savedFolderBookmark")
            
            print("✅ Stored file bookmark: \(fileURL.path)")
            print("✅ Stored folder bookmark: \(folderURL.path)")
        } catch {
            print("❌ Error creating bookmarks: \(error.localizedDescription)")
            errorMessage = "❌ Error creating bookmarks: \(error.localizedDescription)"
        }
    }
    
    /// Renames the selected file using security-scoped bookmarks
    private func renameFile() {
        guard let fileBookmarkData = UserDefaults.standard.data(forKey: "savedFileBookmark"),
              let folderBookmarkData = UserDefaults.standard.data(forKey: "savedFolderBookmark") else {
            errorMessage = "❌ No stored file or folder access. Requesting access..."
            print(errorMessage!)
            requestFolderAccess()
            return
        }
        
        var fileIsStale = false
        var folderIsStale = false
        
        do {
            let folderURL = try URL(resolvingBookmarkData: folderBookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &folderIsStale)
            if folderIsStale {
                errorMessage = "⚠️ Folder bookmark is stale. Requesting new access..."
                requestFolderAccess()
                return
            }
            
            var fileURL = try URL(resolvingBookmarkData: fileBookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &fileIsStale)
            if fileIsStale {
                errorMessage = "⚠️ File bookmark is stale. Requesting new access..."
                requestFolderAccess()
                return
            }
            
            if folderURL.startAccessingSecurityScopedResource() {
                defer { folderURL.stopAccessingSecurityScopedResource() }
                
                if fileURL.startAccessingSecurityScopedResource() {
                    defer { fileURL.stopAccessingSecurityScopedResource() }
                    
                    let newFileURL = fileURL.deletingLastPathComponent().appendingPathComponent(formattedFileName)
                    
                    do {
                        print("🔄 Attempting to rename file: \(fileURL.path) → \(newFileURL.path)")
                        try FileManager.default.moveItem(at: fileURL, to: newFileURL)
                        selectedFileURL = newFileURL
                        print("✅ File renamed successfully: \(newFileURL.lastPathComponent)")
                        errorMessage = nil
                        isFileDropped = false
                        
                        // Show success message temporarily
                        withAnimation {
                            showSuccessMessage = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showSuccessMessage = false
                            }
                        }
                    } catch {
                        errorMessage = "❌ Error renaming file: \(error.localizedDescription)"
                        print(errorMessage!)
                        if error.localizedDescription.contains("permission") {
                            requestFolderAccess()
                        }
                    }
                } else {
                    errorMessage = "❌ Failed to access security-scoped resource for file."
                }
            } else {
                errorMessage = "❌ Failed to access security-scoped resource for folder."
            }
        } catch {
            errorMessage = "❌ Error resolving bookmarks: \(error.localizedDescription)"
        }
    }
    
    /// Requests explicit folder access using NSOpenPanel
    private func requestFolderAccess() {
        let openPanel = NSOpenPanel()
        openPanel.message = "To rename files in this folder, please grant access."
        openPanel.prompt = "Grant Access"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        
        if openPanel.runModal() == .OK, let grantedURL = openPanel.url {
            do {
                let bookmarkData = try grantedURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: "savedFolderBookmark")
                print("✅ Folder access granted: \(grantedURL.path)")
            } catch {
                errorMessage = "❌ Error creating security-scoped bookmark: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "❌ User denied folder access."
        }
    }
}

enum FormattingOption {
    case lowercased, camelCased, hyphenated
}

#Preview {
    ContentView()
}
