import Foundation

/// Service for persisting SelectedFile bookmarks to UserDefaults
class BookmarkPersistenceService {
    
    private let userDefaults: UserDefaults
    private let userDefaultsKey: String
    
    /// Initialize with custom UserDefaults and key (useful for testing)
    /// - Parameters:
    ///   - userDefaults: UserDefaults instance to use
    ///   - key: Key to store bookmarks under
    init(userDefaults: UserDefaults = .standard, key: String = "persistedBookmarks") {
        self.userDefaults = userDefaults
        self.userDefaultsKey = key
    }
    
    /// Saves files to UserDefaults
    /// - Parameter files: Array of SelectedFile to persist
    /// - Throws: Encoding errors
    func save(_ files: [SelectedFile]) throws {
        let encoded = try JSONEncoder().encode(files)
        userDefaults.set(encoded, forKey: userDefaultsKey)
    }
    
    /// Loads files from UserDefaults
    /// - Returns: Array of SelectedFile, or empty array if not found or decoding fails
    func load() -> [SelectedFile] {
        guard let data = userDefaults.data(forKey: userDefaultsKey) else {
            return []
        }
        
        do {
            let decoded = try JSONDecoder().decode([SelectedFile].self, from: data)
            return decoded
        } catch {
            // Log error but return empty array to allow app to continue
            #if DEBUG
            print("Failed to load bookmarks: \(error)")
            #endif
            return []
        }
    }
    
    /// Clears persisted files from UserDefaults
    func clear() {
        userDefaults.removeObject(forKey: userDefaultsKey)
    }
}
