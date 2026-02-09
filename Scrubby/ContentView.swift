//
//  ContentView.swift
//  FileRenamer
//
//  Created by Ryan Graves on 2/18/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - ContentView

struct ContentView: View {
    // MARK: - ViewModels
    @StateObject private var fileProcessingVM = FileProcessingViewModel()
    @StateObject private var uiStateVM = UIStateViewModel()
    @StateObject private var presetManager = PresetManager()
    
    // MARK: - Body
    var body: some View {
        NavigationStack {  // Left Side – File List & File Management
            VStack(spacing: 16) {
                HStack {
                    Text("File Preview")
                        .font(.headline)
                        .padding(.vertical, 4)
                    Spacer()
                    if !fileProcessingVM.selectedFiles.isEmpty {
                        Picker("Thumbnail Size", selection: $uiStateVM.thumbnailSizePreference) {
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
                if fileProcessingVM.selectedFiles.isEmpty {
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
                            uiStateVM.isAdditionalFileImporterPresented = true
                        }
                        .fileImporter(
                            isPresented: $uiStateVM.isAdditionalFileImporterPresented,
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
                        ForEach(fileProcessingVM.selectedFiles.indices, id: \.self) { idx in
                            let file = fileProcessingVM.selectedFiles[idx]
                            FileListItem(
                                thumbnailSizePreference: uiStateVM.thumbnailSizePreference,
                                file: file,
                                selectedFiles: $fileProcessingVM.selectedFiles,
                                processedFileName: fileProcessingVM.previewFileName(for: file, at: idx)
                            )
                        }
                        HStack {
                            Button("Add Files") {
                                uiStateVM.isAdditionalFileImporterPresented = true
                            }
                            .fileImporter(
                                isPresented: $uiStateVM.isAdditionalFileImporterPresented,
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
                            fileProcessingVM.clearFiles()
                        }
                        Spacer()
                    }
                }
                
                
            }
            .padding()
        }
        .inspector(isPresented: $uiStateVM.showInspector) {
            VStack(spacing: 16) {
                HStack {
                    Menu {
                        Button("Find & Replace") {
                            fileProcessingVM.renamingSteps.append(RenamingStep(type: .findReplace(find: "", replace: "")))
                        }
                        Button("Prefix") {
                            fileProcessingVM.renamingSteps.append(RenamingStep(type: .prefix("")))
                        }
                        Button("Suffix") {
                            fileProcessingVM.renamingSteps.append(RenamingStep(type: .suffix("")))
                        }
                        Button("Replace Filename") {
                            fileProcessingVM.renamingSteps.append(RenamingStep(type: .replaceFilenameWith("")))
                        }
                        Button("File Format") {
                            fileProcessingVM.renamingSteps.append(RenamingStep(type: .fileFormat(.none)))
                        }
                        Button("Sequential Numbering") {
                            fileProcessingVM.renamingSteps.append(RenamingStep(type: .sequentialNumbering(start: 1, minDigits: 3, position: .prefix)))
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
                            uiStateVM.showSavePresetDialog = true
                        }
                        Button("Manage Presets...") {
                            uiStateVM.showPresetManagementDialog = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bookmark")
                            Text("Presets")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                RenamingStepsListView(renamingSteps: $fileProcessingVM.renamingSteps)
                
                
                
                Spacer()
                VStack(spacing: 8) {
                    HStack {
                        Picker("Move or Copy", selection: $fileProcessingVM.moveFiles) {
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
                            Text(fileProcessingVM.overwrite ? "Files with the same name will be replaced" : "Files with the same name will get a numbered suffix")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Toggle("Overwrite Files", isOn: $fileProcessingVM.overwrite)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
                .formStyle(.grouped)
                
                if !fileProcessingVM.selectedFiles.isEmpty {
                    HStack {
                        Spacer()
                        Button("Save Files") {
                            uiStateVM.isFolderImporterPresented = true
                        }
                        .fileImporter(
                            isPresented: $uiStateVM.isFolderImporterPresented,
                            allowedContentTypes: [.folder],
                            allowsMultipleSelection: false
                        ) { result in
                            switch result {
                            case .success(let urls):
                                if let folder = urls.first {
                                    saveFiles(to: folder)
                                }
                            case .failure(let error):
                                uiStateVM.showToastMessage("Error selecting folder: \(error.localizedDescription)", isError: true)
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
        .sheet(item: $uiStateVM.fileNeedingBookmarkRefresh) { file in
            VStack(spacing: 16) {
                Text("Refresh Access to File")
                    .font(.headline)
                Text("Access to the file \"\(file.fileName)\" has expired or become invalid.\nPlease re-select the file to update its access permissions.")
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Re-select File") {
                    Task {
                        do {
                            _ = try await fileProcessingVM.refreshBookmark(for: file)
                            uiStateVM.showToastMessage("Access refreshed for \"\(file.fileName)\".", isError: false)
                            uiStateVM.fileNeedingBookmarkRefresh = nil
                        } catch {
                            uiStateVM.showToastMessage("Failed to refresh bookmark: \(error.localizedDescription)", isError: true)
                            uiStateVM.fileNeedingBookmarkRefresh = nil
                        }
                    }
                }
                Button("Cancel") {
                    uiStateVM.fileNeedingBookmarkRefresh = nil
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
                Button(action: { uiStateVM.toggleInspector() }) {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(
            ToastView(message: uiStateVM.toastMessage, isError: uiStateVM.toastIsError, showToast: $uiStateVM.showToast)
                .opacity(uiStateVM.showToast ? 1 : 0)
                .animation(.easeInOut, value: uiStateVM.showToast),
            alignment: .bottom
        )
        // Add Save Preset Dialog
        .sheet(isPresented: $uiStateVM.showSavePresetDialog) {
            VStack(spacing: 16) {
                Text("Save Preset")
                    .font(.headline)
                
                TextField("Preset Name", text: $uiStateVM.newPresetName)
                    .textFieldStyle(.roundedBorder)
                
                if !uiStateVM.presetActionError.isEmpty {
                    Text(uiStateVM.presetActionError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        uiStateVM.showSavePresetDialog = false
                        uiStateVM.presetActionError = ""
                    }
                    .keyboardShortcut(.escape)
                    
                    Button("Save") {
                        saveCurrentAsPreset()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(uiStateVM.newPresetName.isEmpty)
                }
            }
            .padding()
            .frame(width: 350)
        }
        // Add Preset Management Dialog
        .sheet(isPresented: $uiStateVM.showPresetManagementDialog) {
            PresetManagementView(presetManager: presetManager)
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                let importResult = await fileProcessingVM.addFiles(urls)
                if !importResult.errors.isEmpty {
                    uiStateVM.showToastMessage(importResult.errors.first ?? importResult.message, isError: true)
                } else {
                    uiStateVM.showToastMessage(importResult.message, isError: false)
                }
            }
        case .failure(let error):
            uiStateVM.showToastMessage("Error adding files: \(error.localizedDescription)", isError: true)
        }
    }
    
    private func saveFiles(to folder: URL) {
        Task {
            let result = await fileProcessingVM.processFiles(destinationFolder: folder)
            uiStateVM.showToastMessage(result.summaryMessage, isError: result.hasErrors)
            
            // Handle stale bookmarks - show refresh dialog for first stale file
            if let staleError = result.errors.first(where: { $0.message.contains("stale") }) {
                if let file = fileProcessingVM.selectedFiles.first(where: { $0.fileName == staleError.fileName }) {
                    uiStateVM.fileNeedingBookmarkRefresh = file
                }
            }
        }
    }
    
    private func saveCurrentAsPreset() {
        guard !uiStateVM.newPresetName.isEmpty else {
            uiStateVM.presetActionError = "Preset name cannot be empty."
            return
        }
        
        let preset = fileProcessingVM.createPreset(name: uiStateVM.newPresetName)
        
        do {
            try presetManager.savePreset(preset)
            uiStateVM.showSavePresetDialog = false
            uiStateVM.resetDialogState()
            uiStateVM.showToastMessage("Preset saved successfully!", isError: false)
        } catch {
            uiStateVM.presetActionError = "Error saving preset: \(error.localizedDescription)"
        }
    }
    
    private func applyPreset(_ preset: Preset) {
        fileProcessingVM.applyPreset(preset)
        uiStateVM.showToastMessage("Applied preset: \(preset.name)", isError: false)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .frame(width: 800, height: 600)
}
