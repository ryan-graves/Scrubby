import Foundation

/// Pure business logic for applying renaming steps to filenames
struct RenamingEngine {
    /// Applies all renaming steps to a filename at a given index
    /// - Parameters:
    ///   - original: The original filename
    ///   - index: The index of this file in the batch (used for sequential numbering)
    ///   - steps: Array of renaming steps to apply sequentially
    /// - Returns: The transformed filename
    static func processFileName(_ original: String, at index: Int, with steps: [RenamingStep]) -> String {
        let ext = (original as NSString).pathExtension
        var baseName = (original as NSString).deletingPathExtension
        
        for step in steps {
            switch step.type {
            case .findReplace(let find, let replace, let isRegex):
                if !find.isEmpty {
                    if isRegex {
                        baseName = applyRegexReplacement(pattern: find, replacement: replace, to: baseName)
                    } else {
                        baseName = baseName.replacingOccurrences(of: find, with: replace, options: .caseInsensitive)
                    }
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
            case .sequentialNumbering(let start, let minDigits, let position):
                let number = start + index
                let formattedNumber = String(format: "%0\(minDigits)d", number)
                switch position {
                case .prefix:
                    baseName = formattedNumber + baseName
                case .suffix:
                    baseName = baseName + formattedNumber
                }
            }
        }
        
        if !ext.isEmpty {
            baseName += ".\(ext)"
        }
        return baseName
    }
    
    /// Applies a regex pattern replacement to a string
    /// - Parameters:
    ///   - pattern: The regex pattern to match
    ///   - replacement: The replacement string (supports $1, $2 etc. for capture groups)
    ///   - input: The input string to transform
    /// - Returns: The transformed string, or original if regex is invalid
    private static func applyRegexReplacement(pattern: String, replacement: String, to input: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(input.startIndex..., in: input)
            return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: replacement)
        } catch {
            // If regex is invalid, return the original string unchanged
            return input
        }
    }
}
