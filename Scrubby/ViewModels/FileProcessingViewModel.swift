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
                do {
                    try self?.persistenceService.save(files)
                } catch {
                    #if DEBUG
                    print("⚠️ Failed to auto-save bookmarks: \(error.localizedDescription)")
                    assertionFailure("Bookmark persistence failed: \(error)")
                    #endif
                }
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
        
        // Track standardized paths to detect duplicates within batch
        var seenPaths = Set<String>()
        // Initialize with existing files
        for existingFile in selectedFiles {
            var isStale = false
            if let resolvedURL = try? URL(
                resolvingBookmarkData: existingFile.bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                seenPaths.insert(resolvedURL.standardized.path)
            }
        }
        
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
                
                // Check for duplicates using the Set of seen paths
                let standardizedPath = url.standardized.path
                
                if !seenPaths.contains(standardizedPath) {
                    let selectedFile = SelectedFile(
                        fileName: url.lastPathComponent,
                        bookmark: bookmark
                    )
                    newFiles.append(selectedFile)
                    seenPaths.insert(standardizedPath)
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
        // Capture state on main thread before moving to background
        let currentFiles = selectedFiles
        let currentMoveFiles = moveFiles
        let currentOverwrite = overwrite
        let currentRenamingSteps = renamingSteps
        let service = fileProcessingService
        
        // Perform file I/O on background thread
        let result = await Task.detached {
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
                    errorCount: 1,
                    errors: [FileProcessingError(
                        fileName: "destination folder",
                        message: "Could not access folder permissions",
                        kind: .permissionDenied
                    )]
                )
            }
            
            // Build array of (source URL, destination name) tuples
            var filesToProcess: [(source: URL, destinationName: String)] = []
            var resolutionErrors: [FileProcessingError] = []
            
            for (index, selectedFile) in currentFiles.enumerated() {
                do {
                    let resolved = try BookmarkManager.resolveBookmark(selectedFile.bookmark)
                    
                    if resolved.isStale {
                        // Skip stale bookmarks - they need to be refreshed
                        resolutionErrors.append(FileProcessingError(
                            fileId: selectedFile.id,
                            fileName: selectedFile.fileName,
                            message: "Bookmark is stale and needs to be refreshed",
                            kind: .staleBookmark
                        ))
                        resolved.stopAccessing()
                        continue
                    }
                    
                    let newName = RenamingEngine.processFileName(
                        selectedFile.fileName,
                        at: index,
                        with: currentRenamingSteps
                    )
                    filesToProcess.append((source: resolved.url, destinationName: newName))
                    
                    // Note: We don't call stopAccessing() here because the FileProcessingService
                    // needs access to the URLs. We'll stop accessing after processing.
                    
                } catch {
                    resolutionErrors.append(FileProcessingError(
                        fileId: selectedFile.id,
                        fileName: selectedFile.fileName,
                        message: "Could not resolve file URL: \(error.localizedDescription)",
                        kind: .resolutionFailed
                    ))
                }
            }
            
            // Process the files
            let operation: FileProcessingOperation = currentMoveFiles ? .move : .copy
            let collisionStrategy: FileCollisionStrategy = currentOverwrite ? .overwrite : .uniqueName
            
            var result = service.processFiles(
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
            
            return result
        }.value
        
        // Only clear files when all succeeded to allow retrying failed ones
        if result.successCount > 0 && !result.hasErrors {
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
