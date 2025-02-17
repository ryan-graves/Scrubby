//
//  String.swift
//  Scrubby
//
//  Created by Ryan Graves on 2/16/25.
//

extension String {
    /// Converts a string to camelCase, keeping only letters and numbers
    func camelCased() -> String {
        let words = self.cleanedWords()
        guard let first = words.first else { return "" }
        
        let rest = words.dropFirst().map { $0.capitalized }
        return ([first.lowercased()] + rest).joined()
    }
    
    /// Converts a string to a hyphenated, lowercase format
    func hyphenated() -> String {
        return self.cleanedWords().joined(separator: "-").lowercased()
    }
    
    /// Converts a string to lowercase but keeps punctuation (except extra spaces and special characters)
    func cleanLowercased() -> String {
        return self.cleanedForSentence().lowercased()
    }
    
    /// Helper: Extracts words from camelCase, dot-separated, parenthesis-separated, and space-separated strings
    private func cleanedWords() -> [String] {
        var modified = self
        
        // Convert camelCase to spaced words
        modified = modified.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        
        // Replace dots, underscores, hyphens, and parentheses with spaces
        modified = modified.replacingOccurrences(of: "[._()\\-]", with: " ", options: .regularExpression)
        
        // Remove special characters except spaces
        modified = modified.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
        
        // Normalize spaces and return word list
        return modified
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
    }
    
    /// Helper: Cleans string for sentence case (removes special characters but keeps punctuation)
    private func cleanedForSentence() -> String {
        var modified = self
        
        // Normalize camelCase by inserting spaces
        modified = modified.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        
        // Replace dots, underscores, hyphens, and parentheses with spaces
        modified = modified.replacingOccurrences(of: "[._()\\-]", with: " ", options: .regularExpression)
        
        // Remove unwanted special characters (except common punctuation)
        modified = modified.replacingOccurrences(of: "[^a-zA-Z0-9 !?.,]", with: "", options: .regularExpression)
        
        // Normalize spaces
        return modified
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
