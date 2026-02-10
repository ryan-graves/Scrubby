import Foundation

/// Holds a pre-compiled regex for efficient batch processing
struct CompiledRegexStep {
    let regex: NSRegularExpression
    let captureGroupCount: Int
}

/// Pure business logic for applying renaming steps to filenames
struct RenamingEngine {
    
    /// Pre-compiles regex steps for efficient batch processing
    /// - Parameter steps: Array of renaming steps
    /// - Returns: Dictionary mapping step IDs to compiled regex info (only for valid regex steps)
    static func compileRegexSteps(_ steps: [RenamingStep]) -> [UUID: CompiledRegexStep] {
        var compiled: [UUID: CompiledRegexStep] = [:]
        for step in steps {
            if case .findReplace(let find, _, let isRegex) = step.type, isRegex, !find.isEmpty {
                if let regex = try? NSRegularExpression(pattern: find, options: [.caseInsensitive]) {
                    compiled[step.id] = CompiledRegexStep(
                        regex: regex,
                        captureGroupCount: regex.numberOfCaptureGroups
                    )
                }
            }
        }
        return compiled
    }
    
    /// Applies all renaming steps to a filename at a given index
    /// - Parameters:
    ///   - original: The original filename
    ///   - index: The index of this file in the batch (used for sequential numbering)
    ///   - steps: Array of renaming steps to apply sequentially
    ///   - compiledRegex: Optional pre-compiled regex cache for batch processing
    /// - Returns: The transformed filename
    static func processFileName(_ original: String, at index: Int, with steps: [RenamingStep], compiledRegex: [UUID: CompiledRegexStep]? = nil) -> String {
        let ext = (original as NSString).pathExtension
        var baseName = (original as NSString).deletingPathExtension
        
        for step in steps {
            switch step.type {
            case .findReplace(let find, let replace, let isRegex):
                if !find.isEmpty {
                    if isRegex {
                        if let compiledRegex = compiledRegex {
                            // A compiled regex cache was provided; only apply if we have an entry.
                            // Missing entry means invalid regex that failed precompilation - skip to avoid
                            // repeated compilation attempts for each file in batch.
                            if let compiledStep = compiledRegex[step.id] {
                                baseName = applyRegexReplacement(
                                    pattern: find,
                                    replacement: replace,
                                    to: baseName,
                                    compiledRegex: compiledStep
                                )
                            }
                        } else {
                            // No compiled cache provided; compile on demand (for preview/single file).
                            baseName = applyRegexReplacement(
                                pattern: find,
                                replacement: replace,
                                to: baseName,
                                compiledRegex: nil
                            )
                        }
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
    ///   - compiledRegex: Optional pre-compiled regex for batch efficiency
    /// - Returns: The transformed string, or original if regex or template is invalid
    private static func applyRegexReplacement(pattern: String, replacement: String, to input: String, compiledRegex: CompiledRegexStep? = nil) -> String {
        let regex: NSRegularExpression
        let captureGroupCount: Int
        
        if let compiled = compiledRegex {
            // Use pre-compiled regex for efficiency
            regex = compiled.regex
            captureGroupCount = compiled.captureGroupCount
        } else {
            // Compile regex on-demand (for single file or preview)
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                captureGroupCount = regex.numberOfCaptureGroups
            } catch {
                // If regex is invalid, return the original string unchanged
                return input
            }
        }
        
        // Validate that replacement template doesn't reference non-existent capture groups
        // to avoid Objective-C exceptions from stringByReplacingMatches
        if !isValidReplacementTemplate(replacement, captureGroupCount: captureGroupCount) {
            return input
        }
        
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: replacement)
    }
    
    /// Validates that all `$n` references in the replacement template refer to existing capture groups.
    /// This prevents `NSRegularExpression` from raising Objective-C exceptions for invalid templates.
    /// Handles escaped characters (\\$, \\\\, etc.) which are treated as literals.
    /// Rejects dangling `$` (not followed by digit) and trailing backslash.
    /// - Parameters:
    ///   - template: The replacement template string
    ///   - captureGroupCount: The number of capture groups in the regex pattern
    /// - Returns: true if the template is valid, false otherwise
    private static func isValidReplacementTemplate(_ template: String, captureGroupCount: Int) -> Bool {
        var i = template.startIndex
        while i < template.endIndex {
            let char = template[i]
            
            // Handle backslash escapes - must have a character to escape
            if char == "\\" {
                let nextIndex = template.index(after: i)
                if nextIndex < template.endIndex {
                    // Skip both the backslash and the escaped character
                    i = template.index(after: nextIndex)
                    continue
                } else {
                    // Trailing backslash is invalid
                    return false
                }
            }
            
            if char == "$" {
                let nextIndex = template.index(after: i)
                // $ must be followed by a digit to be a valid capture group reference
                if nextIndex < template.endIndex, let firstDigit = template[nextIndex].wholeNumberValue {
                    // Parse the full number
                    var groupNumber = firstDigit
                    var j = template.index(after: nextIndex)
                    while j < template.endIndex, let digit = template[j].wholeNumberValue {
                        groupNumber = groupNumber * 10 + digit
                        j = template.index(after: j)
                    }
                    
                    // $0 refers to entire match (always valid), $1+ must be within capture group count
                    if groupNumber > captureGroupCount {
                        return false
                    }
                    
                    i = j
                    continue
                } else {
                    // Dangling $ (not followed by digit) is invalid
                    return false
                }
            }
            i = template.index(after: i)
        }
        return true
    }
}
