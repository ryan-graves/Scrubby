import Foundation
import AppKit
import UniformTypeIdentifiers

/// Errors that can occur during bookmark operations
enum BookmarkError: Error, LocalizedError {
    case resolutionFailed(String)
    case staleBookmark
    case accessDenied
    case creationFailed(String)
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .resolutionFailed(let details):
            return "Failed to resolve bookmark: \(details)"
        case .staleBookmark:
            return "Bookmark is stale and needs to be refreshed"
        case .accessDenied:
            return "Failed to start accessing security-scoped resource"
        case .creationFailed(let details):
            return "Failed to create bookmark: \(details)"
        case .userCancelled:
            return "File selection was cancelled"
        }
    }
}

/// Represents a resolved security-scoped bookmark with lifecycle management
struct ResolvedBookmark {
    let url: URL
    let isStale: Bool
    private let didStartAccessing: Bool
    
    init(url: URL, isStale: Bool, didStartAccessing: Bool) {
        self.url = url
        self.isStale = isStale
        self.didStartAccessing = didStartAccessing
    }
    
    /// Call when done using the URL to stop accessing the security-scoped resource
    func stopAccessing() {
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

/// Manages security-scoped bookmarks for sandboxed file access
class BookmarkManager {
    
    /// Creates a security-scoped bookmark for a URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: Bookmark data that can be persisted
    /// - Throws: BookmarkError.creationFailed if bookmark creation fails
    static func createBookmark(for url: URL) throws -> Data {
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmark
        } catch {
            throw BookmarkError.creationFailed(error.localizedDescription)
        }
    }
    
    /// Resolves a security-scoped bookmark, starting access
    /// - Parameter data: The bookmark data to resolve
    /// - Returns: ResolvedBookmark with URL and staleness indicator
    /// - Throws: BookmarkError if resolution fails
    static func resolveBookmark(_ data: Data) throws -> ResolvedBookmark {
        var isStale = false
        
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            
            if !didStartAccessing {
                throw BookmarkError.accessDenied
            }
            
            return ResolvedBookmark(url: url, isStale: isStale, didStartAccessing: didStartAccessing)
            
        } catch let error as BookmarkError {
            throw error
        } catch {
            throw BookmarkError.resolutionFailed(error.localizedDescription)
        }
    }
    
    /// Handles stale bookmark by prompting user to reauthorize
    /// - Parameters:
    ///   - oldBookmark: The stale bookmark data (used to set initial directory)
    ///   - fileName: The file name to show in the dialog
    /// - Returns: New bookmark data
    /// - Throws: BookmarkError if user cancels or refresh fails
    @MainActor
    static func refreshBookmark(oldBookmark: Data, fileName: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let panel = NSOpenPanel()
            panel.message = "The app needs access to reauthorize: \(fileName)"
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.item]
            
            // Try to resolve the old bookmark to set the initial directory for better UX
            if let resolved = try? resolveBookmark(oldBookmark) {
                panel.directoryURL = resolved.url.deletingLastPathComponent()
                resolved.stopAccessing()
            }
            
            panel.begin { response in
                guard response == .OK, let url = panel.url else {
                    continuation.resume(throwing: BookmarkError.userCancelled)
                    return
                }
                
                do {
                    let newBookmark = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    continuation.resume(returning: newBookmark)
                } catch {
                    continuation.resume(throwing: BookmarkError.creationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Validates bookmark without starting access
    /// - Parameter data: The bookmark data to validate
    /// - Returns: True if bookmark can be resolved (may still be stale)
    static func validateBookmark(_ data: Data) -> Bool {
        var isStale = false
        do {
            _ = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return true
        } catch {
            return false
        }
    }
}
