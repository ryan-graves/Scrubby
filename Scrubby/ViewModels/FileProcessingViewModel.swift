import Foundation
import Combine

/// Result of file import operation
struct FileImportResult {
    let addedCount: Int
    let skippedCount: Int
    let errors: [String]
    
    var hasErrors: Bool {
        !errors.isEmpty
    }
    
    var message: String {
        if errors.isEmpty && skippedCount == 0 {
            return addedCount == 1 ? "1 file added" : "\(addedCount) files added"
        } else if errors.isEmpty && skippedCount > 0 {
            if addedCount > 0 {
                return "\(addedCount) file(s) added, \(skippedCount) duplicate(s) skipped"
            } else {
                return "No new files added"
            }
        } else {
            return "Added \(addedCount), skipped \(skippedCount), \(errors.count) error(s)"
        }
    }
}

/// ViewModel managing file processing domain logic
@MainActor
class FileProcessingViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var selectedFiles: [SelectedFile] = []
    @Published var renamingSteps: [RenamingStep] = [RenamingStep(type: .fileFormat(.none))]
    @Published var overwrite: Bool = false
    @Published var moveFiles: Bool = false
    @Published var destinationFolderURL: URL? = nil
    
    // MARK: - Services
    
    private let fileProcessingService: FileProcessingService
    private let persistenceService: BookmarkPersistenceService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        fileProcessingService: FileProcessingService = FileProcessingService(),
        persistenceService: BookmarkPersistenceService = BookmarkPersistenceService()
    ) {
        self.fileProcessingService = fileProcessingService
        self.persistenceService = persistenceService
        
        // Load persisted files
        self.selectedFiles = persistenceService.load()
        
        // Auto-save when selectedFiles changes
        $selectedFiles
            .dropFirst() // Skip initial value
            .sink { [weak self] files in
                try? self?.persistenceService.save(files)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Adds files from URLs, creating bookmarks
    /// - Parameter urls: Array of file URLs to add
    /// - Returns: Import result with counts and errors
    func addFiles(_ urls: [URL]) async -> FileImportResult {
        var newFiles: [SelectedFile] = []
        var skippedCount = 0
        var errors: [String] = []
        
        for url in urls {
            // Start accessing the security-scoped resource first
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                // Create a security-scoped bookmark for sandboxed access
                let bookmark = try BookmarkManager.createBookmark(for: url)
                
                // Check for duplicates by comparing file paths
                let standardizedPath = url.standardized.path
                let isDuplicate = selectedFiles.contains { existingFile in
                    var isStale = false
                    if let resolved = try? BookmarkManager.resolveBookmark(existingFile.bookmark) {
                        defer { resolved.stopAccessing() }
                        return resolved.url.standardized.path == standardizedPath
                    }
                    return false
                }
                
                if !isDuplicate {
                    let selectedFile = SelectedFile(
                        fileName: url.lastPathComponent,
                        bookmark: bookmark
                    )
                    newFiles.append(selectedFile)
                } else {
                    skippedCount += 1
                }
            } catch {
                errors.append("Error creating bookmark for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Add new files to the list
        selectedFiles.append(contentsOf: newFiles)
        
        return FileImportResult(
            addedCount: newFiles.count,
            skippedCount: skippedCount,
            errors: errors
        )
    }
    
    /// Removes a file by ID
    /// - Parameter id: The UUID of the file to remove
    func removeFile(id: UUID) {
        selectedFiles.removeAll { $0.id == id }
    }
    
    /// Clears all selected files
    func clearFiles() {
        selectedFiles = []
    }
    
    /// Processes filename preview for a file at index
    /// - Parameters:
    ///   - file: The selected file
    ///   - index: The index of this file in the batch
    /// - Returns: The processed filename
    func previewFileName(for file: SelectedFile, at index: Int) -> String {
        return RenamingEngine.processFileName(
            file.fileName,
            at: index,
            with: renamingSteps
        )
    }
    
    /// Executes the file processing operation
    /// - Parameter destinationFolder: The folder to save files to
    /// - Returns: Processing result
    func processFiles(destinationFolder: URL) async -> FileProcessingResult {
        // Start security-scoped access to destination folder
        let didStartAccessing = destinationFolder.startAccessingSecurityScopedResource()
        
        defer {
            if didStartAccessing {
                destinationFolder.stopAccessingSecurityScopedResource()
            }
        }
        
        guard didStartAccessing else {
            return FileProcessingResult(
                successCount: 0,
                errorCount: selectedFiles.count,
                errors: [FileProcessingError(
                    fileName: "destination folder",
                    message: "Could not access folder permissions"
                )]
            )
        }
        
        // Build array of (source URL, destination name) tuples
        var filesToProcess: [(source: URL, destinationName: String)] = []
        var resolutionErrors: [FileProcessingError] = []
        
        for (index, selectedFile) in selectedFiles.enumerated() {
            do {
                let resolved = try BookmarkManager.resolveBookmark(selectedFile.bookmark)
                
                if resolved.isStale {
                    // Skip stale bookmarks - they need to be refreshed
                    resolutionErrors.append(FileProcessingError(
                        fileName: selectedFile.fileName,
                        message: "Bookmark is stale and needs to be refreshed"
                    ))
                    resolved.stopAccessing()
                    continue
                }
                
                let newName = previewFileName(for: selectedFile, at: index)
                filesToProcess.append((source: resolved.url, destinationName: newName))
                
                // Note: We don't call stopAccessing() here because the FileProcessingService
                // needs access to the URLs. We'll stop accessing after processing.
                
            } catch {
                resolutionErrors.append(FileProcessingError(
                    fileName: selectedFile.fileName,
                    message: "Could not resolve file URL: \(error.localizedDescription)"
                ))
            }
        }
        
        // Process the files
        let operation: FileProcessingOperation = moveFiles ? .move : .copy
        let collisionStrategy: FileCollisionStrategy = overwrite ? .overwrite : .uniqueName
        
        var result = fileProcessingService.processFiles(
            files: filesToProcess,
            destinationFolder: destinationFolder,
            operation: operation,
            collisionStrategy: collisionStrategy
        )
        
        // Stop accessing all resolved URLs
        for (sourceURL, _) in filesToProcess {
            sourceURL.stopAccessingSecurityScopedResource()
        }
        
        // Add resolution errors to the result
        if !resolutionErrors.isEmpty {
            result = FileProcessingResult(
                successCount: result.successCount,
                errorCount: result.errorCount + resolutionErrors.count,
                errors: result.errors + resolutionErrors
            )
        }
        
        // Clear files if all succeeded
        if result.errorCount == 0 {
            clearFiles()
        }
        
        return result
    }
    
    /// Applies a preset to current state
    /// - Parameter preset: The preset to apply
    func applyPreset(_ preset: Preset) {
        renamingSteps = preset.renamingSteps
        overwrite = preset.overwrite
        moveFiles = preset.moveFiles
    }
    
    /// Creates preset from current state
    /// - Parameter name: Name for the preset
    /// - Returns: New preset with current configuration
    func createPreset(name: String) -> Preset {
        return Preset(
            name: name,
            renamingSteps: renamingSteps,
            overwrite: overwrite,
            moveFiles: moveFiles
        )
    }
    
    /// Handles stale bookmark refresh
    /// - Parameter file: The file with stale bookmark
    /// - Returns: Updated file with new bookmark
    /// - Throws: BookmarkError if refresh fails
    func refreshBookmark(for file: SelectedFile) async throws -> SelectedFile {
        let newBookmark = try await BookmarkManager.refreshBookmark(
            oldBookmark: file.bookmark,
            fileName: file.fileName
        )
        
        // Get the new filename from the refreshed bookmark
        let resolved = try BookmarkManager.resolveBookmark(newBookmark)
        defer { resolved.stopAccessing() }
        
        let updatedFile = SelectedFile(
            id: file.id,
            fileName: resolved.url.lastPathComponent,
            bookmark: newBookmark
        )
        
        // Update in the list
        if let index = selectedFiles.firstIndex(where: { $0.id == file.id }) {
            selectedFiles[index] = updatedFile
        }
        
        return updatedFile
    }
}
