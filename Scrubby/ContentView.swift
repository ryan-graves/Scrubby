//
//  ContentView.swift
//  FileRenamer
//
//  Created by Ryan Graves on 2/18/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - FindReplacePair Struct
struct FindReplacePair: Identifiable, Equatable {
    let id = UUID()
    var find: String = ""
    var replace: String = ""
}

struct ContentView: View {
    // MARK: - State Properties
    @State private var selectedFiles: [URL] = []
    @State private var destinationFolderURL: URL? = nil
    @State private var isFileImporterPresented = false
    @State private var isAdditionalFileImporterPresented = false
    @State private var isFolderImporterPresented = false

    // Rename options...
    @State private var prefix: String = ""
    @State private var suffix: String = ""
    @State private var findReplacePairs: [FindReplacePair] = [FindReplacePair()]
    @State private var fileFormat: FileFormat = .none
    @State private var overwrite: Bool = true
    @State private var moveFiles: Bool = false   // New: if true, move (delete original) rather than copy

    // Toast message states...
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var toastIsError: Bool = false

    // MARK: - Body
    var body: some View {
        HSplitView {
            // Left Side – File List & File Management
            VStack(spacing: 16) {
                HStack {
                    Text("File Preview")
                        .font(.headline)
                        .padding(.vertical, 4)
                    Spacer()
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
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.bottom, 48)
                    .frame(maxHeight: .infinity)
                    
                } else {
                    List {
                        ForEach(selectedFiles, id: \.self) { file in
                            HStack {
                                HStack {
                                    Text(file.lastPathComponent)
                                    Spacer(minLength: 4)
                                }
                                HStack {
                                    Image(systemName: "arrow.right")
                                    Spacer(minLength: 4)
                                    Text(processedFileName(for: file.lastPathComponent))
                                        .foregroundColor(.secondary)
                                }
                                // Minus button to remove the file from the list.
                                Button {
                                    if let index = selectedFiles.firstIndex(of: file) {
                                        selectedFiles.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
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
                    .padding()

                    HStack {
                        Button("Clear selected files") {
                            selectedFiles = []
                        }
                        Spacer()
                    }
                }
            }
            .padding()
            

            // Right Side – Options & Save
            VStack {
                Form {
                    Section("Options") {
                        ForEach($findReplacePairs) { $pair in
                            HStack {
                                VStack(spacing: 4) {
                                    TextField("Find", text: $pair.find)
                                        .padding(6)
                                        .background(.ultraThickMaterial)
                                        .cornerRadius(8)
                                    TextField("Replace", text: $pair.replace)
                                        .padding(6)
                                        .background(.ultraThickMaterial)
                                        .cornerRadius(8)
                                }
                                // Plus Button to add a new find/replace row.
                                Button(action: {
                                    findReplacePairs.append(FindReplacePair())
                                }) {
                                    Image(systemName: "plus.circle")
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.borderless)
                                // Minus Button: Show only if there's more than one row.
                                if findReplacePairs.count > 1 {
                                    Button(action: {
                                        if let index = findReplacePairs.firstIndex(where: { $0.id == pair.id }) {
                                            findReplacePairs.remove(at: index)
                                        }
                                    }) {
                                        Image(systemName: "minus.circle")
                                            .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    Section {
                        // Format Picker
                        Picker("Format", selection: $fileFormat) {
                            ForEach(FileFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                    }
                    Section {
                        VStack(spacing: 4) {
                            TextField("Prefix", text: $prefix)
                                .padding(6)
                                .background(.ultraThickMaterial)
                                .cornerRadius(8)
                            TextField("Suffix", text: $suffix)
                                .padding(6)
                                .background(.ultraThickMaterial)
                                .cornerRadius(8)
                        }
                    }

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
                    }
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Move Files")
                            Text(moveFiles ? "The original file will be removed and replaced" : "Files will be copied to their new name/location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Toggle("Move Files (remove originals)", isOn: $moveFiles)
                            .labelsHidden()
                    }
                }
                .formStyle(.grouped)

                HStack {
                    Spacer()
                    if !selectedFiles.isEmpty {
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
                .padding()
            }
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 350, minHeight: 280)
            .layoutPriority(0)
        }
        .overlay(
            ToastView(message: toastMessage, isError: toastIsError, showToast: $showToast)
                .opacity(showToast ? 1 : 0)
                .animation(.easeInOut, value: showToast),
            alignment: .bottom
        )
    }

    // MARK: - Process Filename
    func processedFileName(for original: String) -> String {
        let ext = (original as NSString).pathExtension
        var baseName = (original as NSString).deletingPathExtension

        // Perform case-insensitive find/replace operations.
        for pair in findReplacePairs {
            if !pair.find.isEmpty {
                baseName = baseName.replacingOccurrences(of: pair.find, with: pair.replace, options: .caseInsensitive, range: nil)
            }
        }

        baseName = baseName.filter { $0.isLetter || $0.isNumber || $0.isWhitespace || $0 == "-" }

        switch fileFormat {
        case .hyphenated:
            baseName = baseName.hyphenated()
        case .camelCased:
            baseName = baseName.camelCased()
        case .lowercaseUnderscored:
            baseName = baseName.cleanedWords().joined(separator: "_").lowercased()
        case .none:
            break
        }

        baseName = "\(prefix)\(baseName)\(suffix)"

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
        
        // Start accessing the destination folder’s security-scoped resource.
        let didStartAccessing = folder.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { folder.stopAccessingSecurityScopedResource() }
        }
        
        guard didStartAccessing else {
            showToastMessage("Could not access folder permissions.", isError: true)
            return
        }
        
        var errorsOccurred = false
        
        // Process each selected file.
        for url in selectedFiles {
            let originalName = url.lastPathComponent
            let newName = processedFileName(for: originalName)
            // Determine the final destination URL.
            let finalDestinationURL: URL = overwrite ? folder.appendingPathComponent(newName)
                                                     : uniqueDestinationURL(for: newName, in: folder)
            // Create a temporary file URL in the destination folder.
            let tempURL = folder.appendingPathComponent("temp_\(UUID().uuidString)_\(newName)")
            
            // Start accessing the source file’s security scope.
            guard url.startAccessingSecurityScopedResource() else {
                showToastMessage("Could not access file: \(originalName)", isError: true)
                continue
            }
            do {
                // First, copy the source file to the temporary location.
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                // If overwriting and a file exists at the final destination, trash it.
                if overwrite, FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                    try FileManager.default.trashItem(at: finalDestinationURL, resultingItemURL: nil)

                }
                
                // Move the temporary file into its final destination.
                try FileManager.default.moveItem(at: tempURL, to: finalDestinationURL)
                
                // If moveFiles is enabled, then trash the original source file.
                if moveFiles {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)

                }
            } catch {
                errorsOccurred = true
                showToastMessage("Error processing \(originalName): \(error.localizedDescription)", isError: true)
                // Clean up any temporary file that may have been created.
                try? FileManager.default.removeItem(at: tempURL)
            }
            url.stopAccessingSecurityScopedResource()
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
}

// MARK: - FileFormat Enum
enum FileFormat: CaseIterable {
    case none, hyphenated, camelCased, lowercaseUnderscored

    var displayName: String {
        switch self {
        case .none: return "None"
        case .hyphenated: return "Hyphenated"
        case .camelCased: return "CamelCase"
        case .lowercaseUnderscored: return "snake_case"
        }
    }
}

// MARK: - ToastView
struct ToastView: View {
    let message: String
    let isError: Bool
    @Binding var showToast: Bool

    var body: some View {
        HStack {
            Text(message)
            Button {
                withAnimation { showToast = false }
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .focusEffectDisabled()
            .frame(width: 16, height: 16)
        }
        .padding(.vertical, 8)
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .background(isError ? Color.red : Color.green)
        .foregroundColor(.white)
        .cornerRadius(8)
        .padding(.top, 10)
        .padding(8)
    }
}


// MARK: - Preview
#Preview {
    ContentView()
        .frame(width: 800, height: 600)
}
