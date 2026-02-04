//
//  ContentView.swift
//  FileRenamer
//
//  Created by Ryan Graves on 2/18/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SelectedFile: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let bookmark: Data
    var resolvedURL: URL? = nil
    
    init(id: UUID = UUID(), fileName: String, bookmark: Data, resolvedURL: URL? = nil) {
        self.id = id
        self.fileName = fileName
        self.bookmark = bookmark
        self.resolvedURL = resolvedURL
    }
    
    /// Resolves the security-scoped URL from this file's bookmark, starting access. Returns (url, isStale) or throws.
    func resolvedSecurityScopedURL() throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
        let accessed = url.startAccessingSecurityScopedResource()
        if !accessed {
            throw NSError(domain: "SecurityScopedURL", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to start accessing security-scoped resource."])
        }
        return (url, isStale)
    }
}

extension SelectedFile: Codable {
    enum CodingKeys: String, CodingKey { case id, fileName, bookmark }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(bookmark, forKey: .bookmark)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = try container.decode(UUID.self, forKey: .id)
        let decodedFileName = try container.decode(String.self, forKey: .fileName)
        let decodedBookmark = try container.decode(Data.self, forKey: .bookmark)
        self.init(id: decodedId, fileName: decodedFileName, bookmark: decodedBookmark, resolvedURL: nil)
    }
}

// MARK: - ContentView

struct ContentView: View {
    // MARK: - Persistent Bookmark Storage Key
    private let bookmarksKey = "persistedBookmarks"
    
    // MARK: - State Properties
    @State private var selectedFiles: [SelectedFile] = [] {
        didSet { saveBookmarksToDefaults() }
    }
    @State private var destinationFolderURL: URL? = nil
    @State private var isFileImporterPresented = false
    @State private var isAdditionalFileImporterPresented = false
    @State private var isFolderImporterPresented = false
    @State private var renamingSteps: [RenamingStep] = [
        RenamingStep(type: .fileFormat(.none))
    ]
    
    @State private var overwrite: Bool = false
    @State private var moveFiles: Bool = false
    @State private var thumbnailSizePreference: ThumbnailSize = .small
    
    // Toast message states...
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var toastIsError: Bool = false
    
    // Preset dialog states...
    @State private var showSavePresetDialog: Bool = false
    @State private var showPresetManagementDialog: Bool = false
    @State private var newPresetName: String = ""
    @State private var presetActionError: String = ""
    @StateObject private var presetManager = PresetManager()
    @State private var showInspector: Bool = true
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    
    // MARK: - New State for Bookmark Refresh Handling
    /// Holds a SelectedFile that has a stale bookmark, requiring user to reauthorize access.
    @State private var fileNeedingBookmarkRefresh: SelectedFile? = nil
    
    // MARK: - Init
    init() {
        loadBookmarksFromDefaults()
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {  // Left Side – File List & File Management
            VStack(spacing: 16) {
                HStack {
                    Text("File Preview")
                        .font(.headline)
                        .padding(.vertical, 4)
                    Spacer()
                    if !selectedFiles.isEmpty {
                        Picker("Thumbnail Size", selection: $thumbnailSizePreference) {
                            ForEach(ThumbnailSize.allCases, id: \.self) { size in
                                Image(systemName: size.systemImage)
                                    .tag(size)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .labelsHidden()
                        .frame(width: 72)
                    }
                }
                if selectedFiles.isEmpty {
                    VStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "character.cursor.ibeam")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("Choose the files you'd like to rename")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        Button("Choose files...") {
                            isAdditionalFileImporterPresented = true
                        }
                        .fileImporter(
                            isPresented: $isAdditionalFileImporterPresented,
                            allowedContentTypes: [.item],
                            allowsMultipleSelection: true
                        ) { result in
                            handleFileImport(result: result)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.bottom, 48)
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(selectedFiles.indices, id: \.self) { idx in
                            let file = selectedFiles[idx]
                            FileListItem(thumbnailSizePreference: thumbnailSizePreference, file: file, selectedFiles: $selectedFiles, processedFileName: processedFileName(for: file.fileName, at: idx))
                        }
                        HStack {
                            Button("Add Files") {
                                isAdditionalFileImporterPresented = true
                            }
                            .fileImporter(
                                isPresented: $isAdditionalFileImporterPresented,
                                allowedContentTypes: [.item],
                                allowsMultipleSelection: true
                            ) { result in
                                handleFileImport(result: result)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.inset)
                    .cornerRadius(8)
                    
                    HStack {
                        Button("Clear selected files") {
                            selectedFiles = []
                        }
                        Spacer()
                    }
                }
                
                
            }
            .padding()
        }
        .inspector(isPresented: $showInspector) {
            VStack(spacing: 16) {
                HStack {
                    Menu {
                        Button("Find & Replace") {
                            renamingSteps.append(RenamingStep(type: .findReplace(find: "", replace: "")))
                        }
                        Button("Prefix") {
                            renamingSteps.append(RenamingStep(type: .prefix("")))
                        }
                        Button("Suffix") {
                            renamingSteps.append(RenamingStep(type: .suffix("")))
                        }
                        Button("Replace Filename") {
                            renamingSteps.append(RenamingStep(type: .replaceFilenameWith("")))
                        }
                        Button("File Format") {
                            renamingSteps.append(RenamingStep(type: .fileFormat(.none)))
                        }
                        Button("Sequential Numbering") {
                            renamingSteps.append(RenamingStep(type: .sequentialNumbering(start: 1, minDigits: 3, position: .prefix)))
                        }
                    } label: {
                        Label("Add Step", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Spacer()
                    Menu {
                        if presetManager.presets.isEmpty {
                            Text("No saved presets")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(presetManager.presets) { preset in
                                Button(preset.name) {
                                    applyPreset(preset)
                                }
                            }
                            Divider()
                        }
                        Button("Save Current as Preset...") {
                            showSavePresetDialog = true
                        }
                        Button("Manage Presets...") {
                            showPresetManagementDialog = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bookmark")
                            Text("Presets")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                RenamingStepsListView(renamingSteps: $renamingSteps)
                
                
                
                Spacer()
                VStack(spacing: 8) {
                    HStack {
                        Picker("Move or Copy", selection: $moveFiles) {
                            VStack(alignment: .leading) {
                                Text("Move files")
                                Text("The original file will be removed and replaced")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(true)
                            .padding(.vertical, 2)
                            VStack(alignment: .leading) {
                                Text("Create copies")
                                Text("Files will be copied to their new name and/or location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(false)
                            .padding(.vertical, 2)
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                        .labelsHidden()
                        Spacer()
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Overwrite Files")
                            Text(overwrite ? "Files with the same name will be replaced" : "Files with the same name will get a numbered suffix")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Toggle("Overwrite Files", isOn: $overwrite)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
                .formStyle(.grouped)
                
                if !selectedFiles.isEmpty {
                    HStack {
                        Spacer()
                        Button("Save Files") {
                            isFolderImporterPresented = true
                        }
                        .fileImporter(
                            isPresented: $isFolderImporterPresented,
                            allowedContentTypes: [.folder],
                            allowsMultipleSelection: false
                        ) { result in
                            switch result {
                            case .success(let urls):
                                if let folder = urls.first {
                                    destinationFolderURL = folder
                                    saveFiles()
                                }
                            case .failure(let error):
                                showToastMessage("Error selecting folder: \(error.localizedDescription)", isError: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .inspectorColumnWidth(min: 400, ideal: 400, max: 400)
            
        }
        // Sheet to prompt user to reselect file if bookmark is stale
        .sheet(item: $fileNeedingBookmarkRefresh) { file in
            VStack(spacing: 16) {
                Text("Refresh Access to File")
                    .font(.headline)
                Text("Access to the file \"\(file.fileName)\" has expired or become invalid.\nPlease re-select the file to update its access permissions.")
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Re-select File") {
                    // Use NSOpenPanel to re-select the file
                    let panel = NSOpenPanel()
                    panel.message = "Please select the file \"\(file.fileName)\" to refresh access permissions."
                    panel.allowedContentTypes = [.item]
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.directoryURL = nil
                    
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            if url.lastPathComponent == file.fileName {
                                do {
                                    // Create new bookmark data with security scope
                                    let newBookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                                    // Update the selectedFiles array with the new bookmark
                                    if let index = selectedFiles.firstIndex(where: { $0.id == file.id }) {
                                        selectedFiles[index] = SelectedFile(fileName: file.fileName, bookmark: newBookmark)
                                        showToastMessage("Access refreshed for \"\(file.fileName)\".", isError: false)
                                    }
                                } catch {
                                    showToastMessage("Failed to create bookmark for \"\(file.fileName)\": \(error.localizedDescription)", isError: true)
                                }
                            } else {
                                showToastMessage("Selected file does not match \"\(file.fileName)\".", isError: true)
                            }
                        } else {
                            showToastMessage("File re-selection cancelled.", isError: true)
                        }
                        // Dismiss the sheet after attempt
                        fileNeedingBookmarkRefresh = nil
                    }
                }
                Button("Cancel") {
                    fileNeedingBookmarkRefresh = nil
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .frame(width: 400)
        }
        .frame(minWidth: 800, minHeight: 580)
        .navigationTitle("FileScrubby")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showInspector.toggle() }) {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(
            ToastView(message: toastMessage, isError: toastIsError, showToast: $showToast)
                .opacity(showToast ? 1 : 0)
                .animation(.easeInOut, value: showToast),
            alignment: .bottom
        )
        // Add Save Preset Dialog
        .sheet(isPresented: $showSavePresetDialog) {
            VStack(spacing: 16) {
                Text("Save Preset")
                    .font(.headline)
                
                TextField("Preset Name", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                
                if !presetActionError.isEmpty {
                    Text(presetActionError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showSavePresetDialog = false
                        presetActionError = ""
                    }
                    .keyboardShortcut(.escape)
                    
                    Button("Save") {
                        saveCurrentAsPreset()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newPresetName.isEmpty)
                }
            }
            .padding()
            .frame(width: 350)
        }
        // Add Preset Management Dialog
        .sheet(isPresented: $showPresetManagementDialog) {
            PresetManagementView(presetManager: presetManager)
        }
        // MARK: - Handle stale bookmark prompt outside save loop
        // When fileNeedingBookmarkRefresh is set, prompt user to refresh bookmark asynchronously
        .onChange(of: fileNeedingBookmarkRefresh) { _, file in
            if let file = file {
                DispatchQueue.main.async {
                    regenerateBookmark(for: file)
                }
            }
        }
    }
    
    // MARK: - Persistent Bookmark Storage
    
    private func saveBookmarksToDefaults() {
        do {
            let encoded = try JSONEncoder().encode(selectedFiles)
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
        } catch {
            print("Failed to save bookmarks: \(error)")
        }
    }
    
    private func loadBookmarksFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([SelectedFile].self, from: data)
            selectedFiles = decoded
        } catch {
            print("Failed to load bookmarks: \(error)")
        }
    }
    
    // MARK: - File Import Handler
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var newSelectedFiles: [SelectedFile] = []
            for url in urls {
                // Check for duplicates by fileName
                if !selectedFiles.contains(where: { $0.fileName == url.lastPathComponent }) {
                    do {
                        // Create a security-scoped bookmark for sandboxed access
                        let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        let selectedFile = SelectedFile(fileName: url.lastPathComponent, bookmark: bookmark)
                        newSelectedFiles.append(selectedFile)
                    } catch {
                        showToastMessage("Error creating bookmark for \(url.lastPathComponent): \(error.localizedDescription)", isError: true)
                    }
                }
            }
            if newSelectedFiles.isEmpty {
                showToastMessage("No new files added.", isError: false)
            } else {
                selectedFiles.append(contentsOf: newSelectedFiles)
                showToastMessage("\(newSelectedFiles.count) files added.", isError: false)
            }
        case .failure(let error):
            showToastMessage("Error adding files: \(error.localizedDescription)", isError: true)
        }
    }
    
    // MARK: - Process Filename
    func processedFileName(for original: String, at index: Int) -> String {
        let ext = (original as NSString).pathExtension
        var baseName = (original as NSString).deletingPathExtension
        
        for step in renamingSteps {
            switch step.type {
            case .findReplace(let find, let replace):
                if !find.isEmpty {
                    baseName = baseName.replacingOccurrences(of: find, with: replace, options: .caseInsensitive)
                }
            case .prefix(let value):
                baseName = value + baseName
            case .suffix(let value):
                baseName = baseName + value
            case .fileFormat(let format):
                switch format {
                case .hyphenated:
                    baseName = baseName.hyphenated()
                case .camelCased:
                    baseName = baseName.camelCased()
                case .lowercaseUnderscored:
                    baseName = baseName.cleanedWords().joined(separator: "_").lowercased()
                case .none:
                    break
                }
            case .replaceFilenameWith(let value):
                baseName = value
            case .sequentialNumbering(let start, let minDigits, let position):
                let number = start + index
                let formattedNumber = String(format: "%0\(minDigits)d", number)
                switch position {
                case .prefix:
                    baseName = formattedNumber + baseName
                case .suffix:
                    baseName = baseName + formattedNumber
                }
            }
        }
        
        if !ext.isEmpty {
            baseName += ".\(ext)"
        }
        return baseName
    }
    
    // MARK: - Save Files
    func saveFiles() {
        guard let folder = destinationFolderURL else {
            showToastMessage("No destination folder selected.", isError: true)
            return
        }
        
        // Access the folder with security scope for sandbox compliance
        let didStartAccessing = folder.startAccessingSecurityScopedResource()
        
        defer {
            if didStartAccessing {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        
        guard didStartAccessing else {
            showToastMessage("Could not access folder permissions.", isError: true)
            return
        }
        
        var errorsOccurred = false
        
        for (index, selectedFile) in selectedFiles.enumerated() {
            // Resolve URL from bookmark data and start security-scoped access
            var resolvedURL: URL
            var isStale: Bool
            do {
                let resolved = try selectedFile.resolvedSecurityScopedURL()
                resolvedURL = resolved.url
                isStale = resolved.isStale
                if isStale {
                    // Handle stale bookmark by prompting user to reselect file and refresh bookmark
                    fileNeedingBookmarkRefresh = selectedFile
                    resolvedURL.stopAccessingSecurityScopedResource()
                    errorsOccurred = true
                    continue
                }
            } catch {
                showToastMessage("Could not resolve file URL for: \(selectedFile.fileName)", isError: true)
                errorsOccurred = true
                continue
            }
            
            // Ensure that we stop accessing the security-scoped resource when done
            defer {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
            
            let originalName = selectedFile.fileName
            let newName = processedFileName(for: originalName, at: index)
            
            // Determine final destination URL, handling overwrite option
            let finalDestinationURL: URL = overwrite
            ? folder.appendingPathComponent(newName)
            : uniqueDestinationURL(for: newName, in: folder)
            
            // Use a temporary URL during copy/move operations to avoid partial file overwrites
            let tempURL = folder.appendingPathComponent("temp_\(UUID().uuidString)_\(newName)")
            
            do {
                try FileManager.default.copyItem(at: resolvedURL, to: tempURL)
                
                if overwrite, FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                    try FileManager.default.trashItem(at: finalDestinationURL, resultingItemURL: nil)
                }
                
                try FileManager.default.moveItem(at: tempURL, to: finalDestinationURL)
                
                if moveFiles {
                    try FileManager.default.trashItem(at: resolvedURL, resultingItemURL: nil)
                }
                
            } catch {
                errorsOccurred = true
                showToastMessage("Error processing \(originalName): \(error.localizedDescription)", isError: true)
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
        
        if !errorsOccurred {
            showToastMessage("Files processed successfully!", isError: false)
        }
    }
    
    // MARK: - Unique Destination URL Helper
    func uniqueDestinationURL(for fileName: String, in folder: URL) -> URL {
        let fileNameNSString = fileName as NSString
        let base = fileNameNSString.deletingPathExtension
        let ext = fileNameNSString.pathExtension
        
        var candidate = folder.appendingPathComponent(fileName)
        var counter = 1
        
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newFileName = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
            candidate = folder.appendingPathComponent(newFileName)
            counter += 1
        }
        return candidate
    }
    
    // MARK: - Toast Helper
    func showToastMessage(_ message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showToast = false }
        }
    }
    
    // MARK: - Preset Helpers
    func saveCurrentAsPreset() {
        guard !newPresetName.isEmpty else {
            presetActionError = "Preset name cannot be empty."
            return
        }
        
        let preset = Preset(
            name: newPresetName,
            renamingSteps: renamingSteps,
            overwrite: overwrite,
            moveFiles: moveFiles
        )
        
        do {
            try presetManager.savePreset(preset)
            showSavePresetDialog = false
            newPresetName = ""
            presetActionError = ""
            showToastMessage("Preset saved successfully!", isError: false)
        } catch {
            presetActionError = "Error saving preset: \(error.localizedDescription)"
        }
    }
    
    func applyPreset(_ preset: Preset) {
        renamingSteps = preset.renamingSteps
        overwrite = preset.overwrite
        moveFiles = preset.moveFiles
        showToastMessage("Applied preset: \(preset.name)", isError: false)
    }
    
    // MARK: - New Method to Regenerate Bookmark for a Selected File
    /// Prompts the user to reauthorize access to a specific file that has a stale bookmark.
    private func regenerateBookmark(for file: SelectedFile) {
        // Use NSOpenPanel to prompt for file access
        let panel = NSOpenPanel()
        panel.message = "The app needs access to reauthorize: \(file.fileName)"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]
        panel.directoryURL = nil // Let user pick original location
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            showToastMessage("File access was not reauthorized for \(file.fileName).", isError: true)
            fileNeedingBookmarkRefresh = nil
            return
        }
        do {
            let newBookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            // Update the bookmark in selectedFiles and persist
            if let idx = selectedFiles.firstIndex(where: { $0.id == file.id }) {
                selectedFiles[idx] = SelectedFile(fileName: url.lastPathComponent, bookmark: newBookmark)
            }
            saveBookmarksToDefaults()
            showToastMessage("Bookmark refreshed for \(file.fileName). Try renaming again.", isError: false)
        } catch {
            showToastMessage("Failed to refresh bookmark: \(error.localizedDescription)", isError: true)
        }
        fileNeedingBookmarkRefresh = nil
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .frame(width: 800, height: 600)
}

