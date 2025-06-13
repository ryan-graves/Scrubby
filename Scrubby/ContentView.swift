//
//  ContentView.swift
//  FileRenamer
//
//  Created by Ryan Graves on 2/18/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    // MARK: - State Properties
    @State private var selectedFiles: [URL] = []
    @State private var destinationFolderURL: URL? = nil
    @State private var isFileImporterPresented = false
    @State private var isAdditionalFileImporterPresented = false
    @State private var isFolderImporterPresented = false
    @State private var renamingSteps: [RenamingStep] = [
        RenamingStep(type: .fileFormat(.none))
    ]
    
    // Rename options...
    @State private var prefix: String = ""
    @State private var suffix: String = ""
    @State private var findReplacePairs: [FindReplacePair] = [FindReplacePair()]
    @State private var fileFormat: FileFormat = .none
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
                            switch result {
                            case .success(let urls):
                                let newFiles = urls.filter { !selectedFiles.contains($0) }
                                if newFiles.isEmpty {
                                    showToastMessage("No new files added.", isError: false)
                                } else {
                                    selectedFiles.append(contentsOf: newFiles)
                                    showToastMessage("\(newFiles.count) files added.", isError: false)
                                }
                            case .failure(let error):
                                showToastMessage("Error adding files: \(error.localizedDescription)", isError: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.bottom, 48)
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(selectedFiles, id: \.self) { file in
                            FileListItem(thumbnailSizePreference: thumbnailSizePreference, file: file, selectedFiles: $selectedFiles, processedFileName: processedFileName(for: file.lastPathComponent))
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
                                switch result {
                                case .success(let urls):
                                    let newFiles = urls.filter { !selectedFiles.contains($0) }
                                    if newFiles.isEmpty {
                                        showToastMessage("No new files added.", isError: false)
                                    } else {
                                        selectedFiles.append(contentsOf: newFiles)
                                        showToastMessage("\(newFiles.count) files added.", isError: false)
                                    }
                                case .failure(let error):
                                    showToastMessage("Error adding files: \(error.localizedDescription)", isError: true)
                                }
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
                    Text(overwrite ? "Files with the same name will be replaced" : "Files with the same name will get a numbered suffix")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
    }
    
    // MARK: - Process Filename
    func processedFileName(for original: String) -> String {
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
        
        let didStartAccessing = folder.startAccessingSecurityScopedResource()
        
        defer {
            if didStartAccessing { folder.stopAccessingSecurityScopedResource() }
        }
        
        guard didStartAccessing else {
            showToastMessage("Could not access folder permissions.", isError: true)
            return
        }
        
        var errorsOccurred = false
        
        for url in selectedFiles {
            let originalName = url.lastPathComponent
            let newName = processedFileName(for: originalName)
            let finalDestinationURL: URL = overwrite
            ? folder.appendingPathComponent(newName)
            : uniqueDestinationURL(for: newName, in: folder)
            
            let tempURL = folder.appendingPathComponent("temp_\(UUID().uuidString)_\(newName)")
            
            guard url.startAccessingSecurityScopedResource() else {
                showToastMessage("Could not access file: \(originalName)", isError: true)
                continue
            }
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                if overwrite, FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                    try FileManager.default.trashItem(at: finalDestinationURL, resultingItemURL: nil)
                }
                
                try FileManager.default.moveItem(at: tempURL, to: finalDestinationURL)
                
                if moveFiles {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                }
                
            } catch {
                errorsOccurred = true
                showToastMessage("Error processing \(originalName): \(error.localizedDescription)", isError: true)
                try? FileManager.default.removeItem(at: tempURL)
            }
            url.stopAccessingSecurityScopedResource()
        }
        
        if !errorsOccurred {
            showToastMessage("Files processed successfully!", isError: false)
        } else {
            print("DEBUG: File save completed with errors.")
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
}

// MARK: - Preview
#Preview {
    ContentView()
        .frame(width: 800, height: 600)
}
