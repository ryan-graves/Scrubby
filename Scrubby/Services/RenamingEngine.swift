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
}
