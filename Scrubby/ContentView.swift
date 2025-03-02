//
//  ContentView.swift
//  FileRenamer
//
//  Created by Ryan Graves on 2/18/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import QuickLookThumbnailing

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
                        .buttonStyle(.bordered)
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
            
            // Right Side – Options & Save
            VStack(spacing: 16) {
                RenamingStepsListView(renamingSteps: $renamingSteps)
                
                Menu("Add Step") {
                    Button("Find & Replace") {
                        renamingSteps.append(RenamingStep(type: .findReplace(find: "", replace: "")))
                    }
                    Button("Prefix") {
                        renamingSteps.append(RenamingStep(type: .prefix("")))
                    }
                    Button("Suffix") {
                        renamingSteps.append(RenamingStep(type: .suffix("")))
                    }
                    Button("File Format") {
                        renamingSteps.append(RenamingStep(type: .fileFormat(.none)))
                    }
                }
                .padding(.top, 4)
                Spacer()
                VStack(spacing: 8) {
//                    HStack {
//                        Text("File Handling Preferences")
//                            .font(.headline)
//                        Spacer()
//                    }
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
                .background(Color(NSColor.controlBackgroundColor))
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
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 350, minHeight: 280)
            .layoutPriority(0)
        }
        .frame(minWidth: 800, minHeight: 580)
        .navigationTitle("FileScrubby")
        .background(Color.clear)
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
}

// MARK: - FileFormat Enum
enum FileFormat: CaseIterable {
    case none, hyphenated, camelCased, lowercaseUnderscored
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .hyphenated: return "lowercase-hyphenated"
        case .camelCased: return "camelCase"
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

// MARK: - Unified Model
struct RenamingStep: Identifiable, Equatable {
    let id = UUID()
    var type: RenamingStepType
}

enum RenamingStepType: Equatable {
    case findReplace(find: String, replace: String)
    case prefix(String)
    case suffix(String)
    case fileFormat(FileFormat)
}

// MARK: - RenamingStepsListView
struct RenamingStepsListView: View {
    @Binding var renamingSteps: [RenamingStep]
    @State private var draggingStep: RenamingStep?

    var body: some View {
        VStack(spacing: 8) {
            ForEach($renamingSteps) { $step in
                RenamingStepRow(
                    step: $step,
                    draggingStep: $draggingStep,
                    removeAction: {
                        if let index = renamingSteps.firstIndex(where: { $0.id == step.id }) {
                            renamingSteps.remove(at: index)
                        }
                    }
                )
                .onDrag {
                    self.draggingStep = step
                    return NSItemProvider(object: step.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: StepDropDelegate(item: step, steps: $renamingSteps, current: $draggingStep))
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
        }
        .listStyle(.plain)
        .onChange(of: draggingStep) { newValue in
            // If a drag is active, schedule a reset after 2 seconds.
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if draggingStep != nil {
                        draggingStep = nil
                        print("DEBUG: Dragging state reset after timeout")
                    }
                }
            }
        }
    }
}

struct RenamingStepRow: View {
    @Binding var step: RenamingStep
    @Binding var draggingStep: RenamingStep?
    let removeAction: () -> Void
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Your row content:
            HStack {
                if isHovering {
                    Image(systemName: "arrow.up.and.down.square.fill")
                        .foregroundStyle(.tint)
                } else {
                    Image(systemName: "arrow.up.and.down.square.fill")
                        .foregroundStyle(.tertiary)
                }
                switch step.type {
                case .findReplace(let find, let replace):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Find & Replace").font(.headline)
                        HStack {
                            TextField("Find", text: Binding(
                                get: { find },
                                set: { newValue in
                                    step.type = .findReplace(find: newValue, replace: replace)
                                }
                            ))
                            .onDrop(of: [UTType](), isTargeted: nil) { _ in false }
                            .padding(6)
                            .background(Color(NSColor.quaternarySystemFill))
                            .cornerRadius(6)
                            TextField("Replace", text: Binding(
                                get: { replace },
                                set: { newValue in
                                    step.type = .findReplace(find: find, replace: newValue)
                                }
                            ))
                            .onDrop(of: [UTType](), isTargeted: nil) { _ in false }
                            .padding(6)
                            .background(Color(NSColor.quaternarySystemFill))
                            .cornerRadius(6)
                        }
                    }
                case .prefix(let value):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prefix").font(.headline)
                        TextField("Prefix", text: Binding(
                            get: { value },
                            set: { newValue in
                                step.type = .prefix(newValue)
                            }
                        ))
                        .padding(6)
                        .background(Color(NSColor.quaternarySystemFill))
                        .cornerRadius(6)
                    }
                    .onDrop(of: [UTType](), isTargeted: nil) { _ in false }
                case .suffix(let value):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suffix").font(.headline)
                        TextField("Suffix", text: Binding(
                            get: { value },
                            set: { newValue in
                                step.type = .suffix(newValue)
                            }
                        ))
                        .padding(6)
                        .background(Color(NSColor.quaternarySystemFill))
                        .cornerRadius(6)
                    }
                    .onDrop(of: [UTType](), isTargeted: nil) { _ in false }
                case .fileFormat(let format):
                    HStack(alignment: .top, spacing: 16) {
                        Text("Format").font(.headline)
                        HStack {
                            Picker("Format", selection: Binding(
                                get: {
                                    if case let .fileFormat(currentFormat) = step.type {
                                        return currentFormat
                                    }
                                    return .none
                                },
                                set: { newValue in
                                    step.type = .fileFormat(newValue)
                                }
                            )) {
                                ForEach(FileFormat.allCases, id: \.self) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                            Spacer()
                        }
                        .padding(6)
                        .cornerRadius(6)
                    }
                    .onDrop(of: [UTType](), isTargeted: nil) { _ in false }
                }
                Spacer(minLength: 0)
            }
            .textFieldStyle(.plain)
            .padding(.vertical, 8)
            .padding(.leading, 8)
            .padding(.trailing, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            if isHovering {
                Button(action: removeAction) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        // Set opacity to 0 if this step is currently being dragged.
        .opacity(draggingStep?.id == step.id ? 0 : 1)
        .onHover { hovering in
            withAnimation { isHovering = hovering }
        }
    }
}

struct StepDropDelegate: DropDelegate {
    let item: RenamingStep
    @Binding var steps: [RenamingStep]
    @Binding var current: RenamingStep?

    func dropEntered(info: DropInfo) {
        guard let current = current, current != item,
              let fromIndex = steps.firstIndex(of: current),
              let toIndex = steps.firstIndex(of: item)
        else { return }

        if steps[toIndex] != current {
            withAnimation {
                steps.move(fromOffsets: IndexSet(integer: fromIndex),
                           toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }

    // Remove dropExited altogether.

    func performDrop(info: DropInfo) -> Bool {
        // Delay clearing slightly (0.3 seconds) so the drag preview fades.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.current = nil
            print("DEBUG: Dragging state cleared in performDrop")
        }
        return true
    }
}

enum ThumbnailSize: String, CaseIterable {
    case small
//    case medium
    case large

    var size: CGSize {
        switch self {
        case .small:
            return CGSize(width: 24, height: 24)
        case .large:
            return CGSize(width: 128, height: 128)
        }
    }
    
    var systemImage: String {
        switch self {
        case .small:
            return "square.resize.down"
//        case .medium:
//            return "square"
        case .large:
            return "square.resize.up"
        }
    }
}

// MARK: - FileThumbnailView
struct FileThumbnailView: View {
    let url: URL
    let thumbnailSize: ThumbnailSize

    @State private var thumbnailImage: NSImage? = nil

    var body: some View {
        Group {
            if let thumbnailImage = thumbnailImage {
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: thumbnailSize.size.width, height: thumbnailSize.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: thumbnailSize.size.width, height: thumbnailSize.size.height)
                    .overlay(ProgressView())
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(fileAt: url,
                                                   size: CGSize(width: 256, height: 256),
                                                   scale: scale,
                                                   representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { (thumbnail, error) in
            if let thumbnail = thumbnail {
                DispatchQueue.main.async {
                    thumbnailImage = thumbnail.nsImage
                    print("DEBUG: Thumbnail loaded for \(url.lastPathComponent)")
                }
            } else {
                print("DEBUG: Error generating thumbnail for \(url.lastPathComponent): \(String(describing: error))")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .frame(width: 800, height: 600)
}

struct FileListItem: View {
    var thumbnailSizePreference: ThumbnailSize
    var file: URL
    @Binding var selectedFiles: [URL]
    var processedFileName: String
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: thumbnailSizePreference == .large ? 16 : 8) {
            FileThumbnailView(url: file, thumbnailSize: thumbnailSizePreference)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            HStack(spacing: 16) {
                Text(file.lastPathComponent)
                Spacer(minLength: 4)
            }
            HStack(spacing: 16) {
                Image(systemName: "arrow.right")
                Text(processedFileName)
                    .foregroundColor(.secondary)
                Spacer(minLength: 4)
            }
            HStack {
                Spacer()
                if isHovering {
                    Button {
                        if let index = selectedFiles.firstIndex(of: file) {
                            selectedFiles.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .padding(4)
                }
            }
            .frame(width: 32)
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation { isHovering = hovering }
        }
        
    }
}
