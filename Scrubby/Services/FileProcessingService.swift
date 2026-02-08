import Foundation

/// Defines how files should be processed
enum FileProcessingOperation {
    case copy  /// Copy files to destination, keep originals
    case move  /// Move files to destination, delete originals
}

/// Defines how to handle filename collisions
enum FileCollisionStrategy {
    case overwrite     /// Replace existing files
    case uniqueName    /// Add _1, _2, etc. to avoid collision
}

/// Result of file processing operation
struct FileProcessingResult {
    let successCount: Int
    let errorCount: Int
    let errors: [FileProcessingError]
    
    var hasErrors: Bool {
        errorCount > 0
    }
    
    var summaryMessage: String {
        if errorCount == 0 {
            return "All \(successCount) files processed successfully!"
        } else if successCount > 0 {
            return "\(successCount) files processed, \(errorCount) failed"
        } else {
            return "Failed to process files"
        }
    }
}

/// Represents an error during file processing
struct FileProcessingError: Identifiable {
    let id = UUID()
    let fileName: String
    let message: String
}

/// Service for handling file system operations
class FileProcessingService {
    
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    /// Processes files by copying or moving them to destination folder
    /// - Parameters:
    ///   - files: Array of (source URL, destination name) tuples
    ///   - destinationFolder: Target folder URL
    ///   - operation: Copy or move operation
    ///   - collisionStrategy: How to handle filename conflicts
    /// - Returns: Processing result with success/error counts
    func processFiles(
        files: [(source: URL, destinationName: String)],
        destinationFolder: URL,
        operation: FileProcessingOperation,
        collisionStrategy: FileCollisionStrategy
    ) -> FileProcessingResult {
        var successCount = 0
        var errors: [FileProcessingError] = []
        
        for (sourceURL, destinationName) in files {
            // Sanitize destination name to prevent path traversal
            let sanitizedName = sanitizeFileName(destinationName)
            
            // Generate temp URL outside try block so it's accessible in catch
            let tempURL = destinationFolder.appendingPathComponent("temp_\(UUID().uuidString)_\(sanitizedName)")
            
            do {
                // Determine final destination URL
                let finalDestinationURL: URL
                switch collisionStrategy {
                case .overwrite:
                    finalDestinationURL = destinationFolder.appendingPathComponent(sanitizedName)
                case .uniqueName:
                    finalDestinationURL = uniqueDestinationURL(for: sanitizedName, in: destinationFolder)
                }
                
                // Check if source and destination are the same file (in-place rename)
                let standardizedSource = sourceURL.standardizedFileURL
                let standardizedDestination = finalDestinationURL.standardizedFileURL
                
                if standardizedSource == standardizedDestination {
                    // Skip processing - source and destination are identical
                    successCount += 1
                    continue
                }
                
                // Copy to temp location
                try fileManager.copyItem(at: sourceURL, to: tempURL)
                
                // If overwriting, trash the existing file first (but never the source)
                if case .overwrite = collisionStrategy {
                    if fileManager.fileExists(atPath: finalDestinationURL.path),
                       standardizedDestination != standardizedSource {
                        try fileManager.trashItem(at: finalDestinationURL, resultingItemURL: nil)
                    }
                }
                
                // Move from temp to final location
                try fileManager.moveItem(at: tempURL, to: finalDestinationURL)
                
                // If move operation, trash the original (but never the destination)
                // Use try? so trashing failure doesn't invalidate the already-completed move
                if case .move = operation,
                   standardizedSource != standardizedDestination {
                    try? fileManager.trashItem(at: sourceURL, resultingItemURL: nil)
                }
                
                successCount += 1
                
            } catch {
                errors.append(FileProcessingError(
                    fileName: (sourceURL.lastPathComponent),
                    message: error.localizedDescription
                ))
                
                // Clean up temp file if it exists (using the same tempURL from above)
                try? fileManager.removeItem(at: tempURL)
            }
        }
        
        return FileProcessingResult(
            successCount: successCount,
            errorCount: errors.count,
            errors: errors
        )
    }
    
    /// Sanitizes a filename by removing path separators and normalizing to a single path component
    /// - Parameter fileName: The filename to sanitize
    /// - Returns: A safe filename without path traversal characters
    private func sanitizeFileName(_ fileName: String) -> String {
        // Remove path separators and components like ".." that could traverse directories
        let components = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\:"))
        let safeName = components.joined(separator: "_")
        
        // Remove leading and trailing dots to prevent hidden files or relative path issues
        let trimmed = safeName.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        
        // If empty after sanitization, use a fallback
        return trimmed.isEmpty ? "file" : trimmed
    }
    
    /// Generates a unique destination URL by appending _1, _2, etc. if file exists
    /// - Parameters:
    ///   - fileName: The desired filename
    ///   - folder: The destination folder
    /// - Returns: A unique URL that doesn't conflict with existing files
    func uniqueDestinationURL(for fileName: String, in folder: URL) -> URL {
        let fileNameNSString = fileName as NSString
        let base = fileNameNSString.deletingPathExtension
        let ext = fileNameNSString.pathExtension
        
        var candidate = folder.appendingPathComponent(fileName)
        var counter = 1
        
        while fileManager.fileExists(atPath: candidate.path) {
            let newFileName = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
            candidate = folder.appendingPathComponent(newFileName)
            counter += 1
        }
        return candidate
    }
}
