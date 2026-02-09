//
//  ScrubbyTests.swift
//  ScrubbyTests
//
//  Created by Ryan Graves on 2/16/25.
//

import Testing
import Foundation
@testable import FileScrubby

// MARK: - RenamingStep Tests

struct RenamingStepTests {

    @Test("RenamingStep findReplace initializes with correct values")
    func testFindReplaceStepInitialization() async throws {
        let step = RenamingStep(type: .findReplace(find: "foo", replace: "bar", isRegex: false))
        if case let .findReplace(find, replace, isRegex) = step.type {
            #expect(find == "foo")
            #expect(replace == "bar")
            #expect(isRegex == false)
        } else {
            #expect(Bool(false), "Expected findReplace type")
        }
    }

    @Test("RenamingStep prefix initializes correctly")
    func testPrefixStepInitialization() async throws {
        let step = RenamingStep(type: .prefix("pre_"))
        if case let .prefix(prefix) = step.type {
            #expect(prefix == "pre_")
        } else {
            #expect(Bool(false), "Expected prefix type")
        }
    }

    @Test("RenamingStep suffix initializes correctly")
    func testSuffixStepInitialization() async throws {
        let step = RenamingStep(type: .suffix("_suf"))
        if case let .suffix(suffix) = step.type {
            #expect(suffix == "_suf")
        } else {
            #expect(Bool(false), "Expected suffix type")
        }
    }

    @Test("RenamingStep fileFormat initializes with correct enum")
    func testFileFormatStepInitialization() async throws {
        let step = RenamingStep(type: .fileFormat(.camelCased))
        if case let .fileFormat(format) = step.type {
            #expect(format == .camelCased)
        } else {
            #expect(Bool(false), "Expected fileFormat type")
        }
    }
    
    @Test("RenamingStep sequentialNumbering initializes correctly")
    func testSequentialNumberingStepInitialization() async throws {
        let step = RenamingStep(type: .sequentialNumbering(start: 5, minDigits: 4, position: .suffix))
        if case let .sequentialNumbering(start, minDigits, position) = step.type {
            #expect(start == 5)
            #expect(minDigits == 4)
            #expect(position == .suffix)
        } else {
            #expect(Bool(false), "Expected sequentialNumbering type")
        }
    }
    
    @Test("RenamingStep encodes and decodes correctly")
    func testRenamingStepCodable() async throws {
        let originalStep = RenamingStep(type: .findReplace(find: "old", replace: "new", isRegex: false))
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalStep)
        
        let decoder = JSONDecoder()
        let decodedStep = try decoder.decode(RenamingStep.self, from: data)
        
        #expect(decodedStep.id == originalStep.id)
        #expect(decodedStep.type == originalStep.type)
    }
}

// MARK: - RenamingEngine Tests

struct RenamingEngineTests {
    
    @Test("RenamingEngine processes find and replace step")
    func testFindReplace() async throws {
        let steps = [RenamingStep(type: .findReplace(find: "old", replace: "new", isRegex: false))]
        let result = RenamingEngine.processFileName("old_file_old.txt", at: 0, with: steps)
        #expect(result == "new_file_new.txt")
    }
    
    @Test("RenamingEngine find and replace is case insensitive")
    func testFindReplaceCaseInsensitive() async throws {
        let steps = [RenamingStep(type: .findReplace(find: "OLD", replace: "new", isRegex: false))]
        let result = RenamingEngine.processFileName("old_file.txt", at: 0, with: steps)
        #expect(result == "new_file.txt")
    }
    
    @Test("RenamingEngine skips empty find string")
    func testFindReplaceEmptyFind() async throws {
        let steps = [RenamingStep(type: .findReplace(find: "", replace: "new", isRegex: false))]
        let result = RenamingEngine.processFileName("original.txt", at: 0, with: steps)
        #expect(result == "original.txt")
    }
    
    @Test("RenamingEngine processes prefix step")
    func testPrefix() async throws {
        let steps = [RenamingStep(type: .prefix("2024_"))]
        let result = RenamingEngine.processFileName("document.pdf", at: 0, with: steps)
        #expect(result == "2024_document.pdf")
    }
    
    @Test("RenamingEngine processes suffix step")
    func testSuffix() async throws {
        let steps = [RenamingStep(type: .suffix("_final"))]
        let result = RenamingEngine.processFileName("report.docx", at: 0, with: steps)
        #expect(result == "report_final.docx")
    }
    
    @Test("RenamingEngine processes replace filename step")
    func testReplaceFilename() async throws {
        let steps = [RenamingStep(type: .replaceFilenameWith("newname"))]
        let result = RenamingEngine.processFileName("oldname.jpg", at: 0, with: steps)
        #expect(result == "newname.jpg")
    }
    
    @Test("RenamingEngine processes hyphenated format")
    func testHyphenatedFormat() async throws {
        let steps = [RenamingStep(type: .fileFormat(.hyphenated))]
        let result = RenamingEngine.processFileName("MyDocument File.txt", at: 0, with: steps)
        #expect(result == "my-document-file.txt")
    }
    
    @Test("RenamingEngine processes camelCase format")
    func testCamelCaseFormat() async throws {
        let steps = [RenamingStep(type: .fileFormat(.camelCased))]
        let result = RenamingEngine.processFileName("my document file.txt", at: 0, with: steps)
        #expect(result == "myDocumentFile.txt")
    }
    
    @Test("RenamingEngine processes snake_case format")
    func testSnakeCaseFormat() async throws {
        let steps = [RenamingStep(type: .fileFormat(.lowercaseUnderscored))]
        let result = RenamingEngine.processFileName("My Document File.txt", at: 0, with: steps)
        #expect(result == "my_document_file.txt")
    }
    
    @Test("RenamingEngine processes none format (no change)")
    func testNoneFormat() async throws {
        let steps = [RenamingStep(type: .fileFormat(.none))]
        let result = RenamingEngine.processFileName("Original Name.txt", at: 0, with: steps)
        #expect(result == "Original Name.txt")
    }
    
    @Test("RenamingEngine processes sequential numbering prefix")
    func testSequentialNumberingPrefix() async throws {
        let steps = [RenamingStep(type: .sequentialNumbering(start: 1, minDigits: 3, position: .prefix))]
        
        let result0 = RenamingEngine.processFileName("photo.jpg", at: 0, with: steps)
        let result1 = RenamingEngine.processFileName("photo.jpg", at: 1, with: steps)
        let result2 = RenamingEngine.processFileName("photo.jpg", at: 2, with: steps)
        
        #expect(result0 == "001photo.jpg")
        #expect(result1 == "002photo.jpg")
        #expect(result2 == "003photo.jpg")
    }
    
    @Test("RenamingEngine processes sequential numbering suffix")
    func testSequentialNumberingSuffix() async throws {
        let steps = [RenamingStep(type: .sequentialNumbering(start: 10, minDigits: 2, position: .suffix))]
        
        let result0 = RenamingEngine.processFileName("image.png", at: 0, with: steps)
        let result1 = RenamingEngine.processFileName("image.png", at: 1, with: steps)
        
        #expect(result0 == "image10.png")
        #expect(result1 == "image11.png")
    }
    
    @Test("RenamingEngine applies multiple steps in sequence")
    func testMultipleSteps() async throws {
        let steps = [
            RenamingStep(type: .findReplace(find: "old", replace: "new", isRegex: false)),
            RenamingStep(type: .prefix("2024_")),
            RenamingStep(type: .suffix("_v1"))
        ]
        let result = RenamingEngine.processFileName("old_document.txt", at: 0, with: steps)
        #expect(result == "2024_new_document_v1.txt")
    }
    
    @Test("RenamingEngine handles file without extension")
    func testFileWithoutExtension() async throws {
        let steps = [RenamingStep(type: .prefix("pre_"))]
        let result = RenamingEngine.processFileName("README", at: 0, with: steps)
        #expect(result == "pre_README")
    }
    
    @Test("RenamingEngine handles empty steps array")
    func testEmptySteps() async throws {
        let steps: [RenamingStep] = []
        let result = RenamingEngine.processFileName("file.txt", at: 0, with: steps)
        #expect(result == "file.txt")
    }
    
    // MARK: - Regex Tests
    
    @Test("RenamingEngine processes basic regex replacement")
    func testRegexBasicReplacement() async throws {
        let steps = [RenamingStep(type: .findReplace(find: "\\d+", replace: "NUM", isRegex: true))]
        let result = RenamingEngine.processFileName("file123test456.txt", at: 0, with: steps)
        #expect(result == "fileNUMtestNUM.txt")
    }
    
    @Test("RenamingEngine processes regex with capture groups")
    func testRegexCaptureGroups() async throws {
        let steps = [RenamingStep(type: .findReplace(find: "(\\w+)-(\\w+)", replace: "$2_$1", isRegex: true))]
        let result = RenamingEngine.processFileName("hello-world.txt", at: 0, with: steps)
        #expect(result == "world_hello.txt")
    }
    
    @Test("RenamingEngine regex handles invalid pattern gracefully")
    func testRegexInvalidPattern() async throws {
        let steps = [RenamingStep(type: .findReplace(find: "[invalid", replace: "new", isRegex: true))]
        let result = RenamingEngine.processFileName("original.txt", at: 0, with: steps)
        // Invalid regex should leave filename unchanged
        #expect(result == "original.txt")
    }
    
    @Test("RenamingEngine regex removes matching text when replace is empty")
    func testRegexRemoveMatches() async throws {
        let steps = [RenamingStep(type: .findReplace(find: "\\s+", replace: "", isRegex: true))]
        let result = RenamingEngine.processFileName("file with spaces.txt", at: 0, with: steps)
        #expect(result == "filewithspaces.txt")
    }
    
    @Test("RenamingEngine regex is case insensitive")
    func testRegexCaseInsensitive() async throws {
        let steps = [RenamingStep(type: .findReplace(find: "test", replace: "REPLACED", isRegex: true))]
        let result = RenamingEngine.processFileName("MyTEST_file.txt", at: 0, with: steps)
        #expect(result == "MyREPLACED_file.txt")
    }
    
    @Test("RenamingStep with regex encodes and decodes correctly")
    func testRenamingStepRegexCodable() async throws {
        let originalStep = RenamingStep(type: .findReplace(find: "\\d+", replace: "NUM", isRegex: true))
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalStep)
        
        let decoder = JSONDecoder()
        let decodedStep = try decoder.decode(RenamingStep.self, from: data)
        
        #expect(decodedStep.id == originalStep.id)
        if case let .findReplace(find, replace, isRegex) = decodedStep.type {
            #expect(find == "\\d+")
            #expect(replace == "NUM")
            #expect(isRegex == true)
        } else {
            #expect(Bool(false), "Expected findReplace type")
        }
    }
    
    @Test("RenamingEngine regex handles invalid replacement template gracefully")
    func testRegexInvalidReplacementTemplate() async throws {
        // Pattern has 1 capture group, but template references $2 which doesn't exist
        let steps = [RenamingStep(type: .findReplace(find: "(\\w+)", replace: "$2", isRegex: true))]
        let result = RenamingEngine.processFileName("hello.txt", at: 0, with: steps)
        // Should return unchanged filename since template is invalid
        #expect(result == "hello.txt")
    }
    
    @Test("RenamingEngine regex allows $0 for full match")
    func testRegexFullMatchReference() async throws {
        // $0 refers to the entire match and should always be valid
        let steps = [RenamingStep(type: .findReplace(find: "\\w+", replace: "[$0]", isRegex: true))]
        let result = RenamingEngine.processFileName("hello.txt", at: 0, with: steps)
        #expect(result == "[hello].txt")
    }
    
    @Test("RenamingEngine regex handles multi-digit capture group references")
    func testRegexMultiDigitCaptureGroup() async throws {
        // Template with $10 should be invalid if there aren't 10 capture groups
        let steps = [RenamingStep(type: .findReplace(find: "(a)(b)", replace: "$10", isRegex: true))]
        let result = RenamingEngine.processFileName("ab.txt", at: 0, with: steps)
        // Should return unchanged since $10 doesn't exist (only 2 capture groups)
        #expect(result == "ab.txt")
    }
}

// MARK: - String Extension Tests

struct StringExtensionTests {
    
    @Test("camelCased converts spaced words")
    func testCamelCasedSpacedWords() async throws {
        let result = "hello world test".camelCased()
        #expect(result == "helloWorldTest")
    }
    
    @Test("camelCased converts hyphenated words")
    func testCamelCasedHyphenated() async throws {
        let result = "hello-world-test".camelCased()
        #expect(result == "helloWorldTest")
    }
    
    @Test("camelCased converts underscored words")
    func testCamelCasedUnderscored() async throws {
        let result = "hello_world_test".camelCased()
        #expect(result == "helloWorldTest")
    }
    
    @Test("camelCased handles existing camelCase")
    func testCamelCasedExistingCamelCase() async throws {
        let result = "helloWorldTest".camelCased()
        #expect(result == "helloWorldTest")
    }
    
    @Test("hyphenated converts spaced words")
    func testHyphenatedSpacedWords() async throws {
        let result = "Hello World Test".hyphenated()
        #expect(result == "hello-world-test")
    }
    
    @Test("hyphenated converts camelCase")
    func testHyphenatedCamelCase() async throws {
        let result = "helloWorldTest".hyphenated()
        #expect(result == "hello-world-test")
    }
    
    @Test("cleanedWords extracts words from mixed format")
    func testCleanedWordsMixed() async throws {
        let result = "hello_world-test.file(name)".cleanedWords()
        #expect(result == ["hello", "world", "test", "file", "name"])
    }
    
    @Test("cleanedWords handles camelCase")
    func testCleanedWordsCamelCase() async throws {
        let result = "helloWorldTest".cleanedWords()
        #expect(result == ["hello", "World", "Test"])
    }
}

// MARK: - FileProcessingResult Tests

struct FileProcessingResultTests {
    
    @Test("FileProcessingResult summaryMessage for all success")
    func testSummaryMessageAllSuccess() async throws {
        let result = FileProcessingResult(successCount: 5, errorCount: 0, errors: [])
        #expect(result.summaryMessage == "All 5 files processed successfully!")
        #expect(result.hasErrors == false)
    }
    
    @Test("FileProcessingResult summaryMessage for partial success")
    func testSummaryMessagePartialSuccess() async throws {
        let result = FileProcessingResult(
            successCount: 3,
            errorCount: 2,
            errors: [FileProcessingError(fileName: "test.txt", message: "Error")]
        )
        #expect(result.summaryMessage == "3 files processed, 2 failed")
        #expect(result.hasErrors == true)
    }
    
    @Test("FileProcessingResult summaryMessage for all failed")
    func testSummaryMessageAllFailed() async throws {
        let result = FileProcessingResult(
            successCount: 0,
            errorCount: 2,
            errors: [FileProcessingError(fileName: "test.txt", message: "Error")]
        )
        #expect(result.summaryMessage == "Failed to process files")
        #expect(result.hasErrors == true)
    }
}

// MARK: - FileImportResult Tests

struct FileImportResultTests {
    
    @Test("FileImportResult message for single file added")
    func testMessageSingleFile() async throws {
        let result = FileImportResult(addedCount: 1, skippedCount: 0, errors: [])
        #expect(result.message == "1 file added")
        #expect(result.hasErrors == false)
    }
    
    @Test("FileImportResult message for multiple files added")
    func testMessageMultipleFiles() async throws {
        let result = FileImportResult(addedCount: 5, skippedCount: 0, errors: [])
        #expect(result.message == "5 files added")
    }
    
    @Test("FileImportResult message with skipped duplicates")
    func testMessageWithSkipped() async throws {
        let result = FileImportResult(addedCount: 3, skippedCount: 2, errors: [])
        #expect(result.message == "3 file(s) added, 2 duplicate(s) skipped")
    }
    
    @Test("FileImportResult message when all skipped")
    func testMessageAllSkipped() async throws {
        let result = FileImportResult(addedCount: 0, skippedCount: 3, errors: [])
        #expect(result.message == "No new files added")
    }
    
    @Test("FileImportResult message with errors")
    func testMessageWithErrors() async throws {
        let result = FileImportResult(addedCount: 2, skippedCount: 1, errors: ["Error 1"])
        #expect(result.message == "Added 2, skipped 1, 1 error(s)")
        #expect(result.hasErrors == true)
    }
}

// MARK: - FileProcessingService Tests

struct FileProcessingServiceTests {
    
    @Test("FileProcessingService uniqueDestinationURL returns original when no conflict")
    func testUniqueDestinationURLNoConflict() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let service = FileProcessingService()
        let result = service.uniqueDestinationURL(for: "newfile.txt", in: tempDir)
        
        #expect(result.lastPathComponent == "newfile.txt")
    }
    
    @Test("FileProcessingService uniqueDestinationURL appends counter on conflict")
    func testUniqueDestinationURLWithConflict() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create existing file
        let existingFile = tempDir.appendingPathComponent("file.txt")
        try "content".write(to: existingFile, atomically: true, encoding: .utf8)
        
        let service = FileProcessingService()
        let result = service.uniqueDestinationURL(for: "file.txt", in: tempDir)
        
        #expect(result.lastPathComponent == "file_1.txt")
    }
    
    @Test("FileProcessingService uniqueDestinationURL increments counter for multiple conflicts")
    func testUniqueDestinationURLMultipleConflicts() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create existing files
        try "content".write(to: tempDir.appendingPathComponent("doc.pdf"), atomically: true, encoding: .utf8)
        try "content".write(to: tempDir.appendingPathComponent("doc_1.pdf"), atomically: true, encoding: .utf8)
        try "content".write(to: tempDir.appendingPathComponent("doc_2.pdf"), atomically: true, encoding: .utf8)
        
        let service = FileProcessingService()
        let result = service.uniqueDestinationURL(for: "doc.pdf", in: tempDir)
        
        #expect(result.lastPathComponent == "doc_3.pdf")
    }
    
    @Test("FileProcessingService processes files with copy operation")
    func testProcessFilesCopy() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("dest")
        
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create source file
        let sourceFile = sourceDir.appendingPathComponent("original.txt")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let service = FileProcessingService()
        let result = service.processFiles(
            files: [(source: sourceFile, destinationName: "renamed.txt")],
            destinationFolder: destDir,
            operation: .copy,
            collisionStrategy: .uniqueName
        )
        
        #expect(result.successCount == 1)
        #expect(result.errorCount == 0)
        #expect(FileManager.default.fileExists(atPath: sourceFile.path)) // Original still exists
        #expect(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("renamed.txt").path))
    }
    
    @Test("FileProcessingService processes files with move operation")
    func testProcessFilesMove() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("dest")
        
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create source file
        let sourceFile = sourceDir.appendingPathComponent("tomove.txt")
        try "test content".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let service = FileProcessingService()
        let result = service.processFiles(
            files: [(source: sourceFile, destinationName: "moved.txt")],
            destinationFolder: destDir,
            operation: .move,
            collisionStrategy: .uniqueName
        )
        
        #expect(result.successCount == 1)
        #expect(result.errorCount == 0)
        // Original is trashed (may or may not exist depending on trash behavior)
        #expect(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("moved.txt").path))
    }
    
    @Test("FileProcessingService handles uniqueName collision strategy")
    func testProcessFilesUniqueNameStrategy() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("dest")
        
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create source file and existing destination file
        let sourceFile = sourceDir.appendingPathComponent("file.txt")
        try "new content".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "existing content".write(to: destDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        
        let service = FileProcessingService()
        let result = service.processFiles(
            files: [(source: sourceFile, destinationName: "file.txt")],
            destinationFolder: destDir,
            operation: .copy,
            collisionStrategy: .uniqueName
        )
        
        #expect(result.successCount == 1)
        #expect(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("file_1.txt").path))
    }
}

// MARK: - Preset Tests

struct PresetTests {
    
    @Test("Preset initializes with correct values")
    func testPresetInitialization() async throws {
        let steps = [RenamingStep(type: .prefix("test_"))]
        let preset = Preset(
            name: "Test Preset",
            renamingSteps: steps,
            overwrite: true,
            moveFiles: false
        )
        
        #expect(preset.name == "Test Preset")
        #expect(preset.renamingSteps.count == 1)
        #expect(preset.overwrite == true)
        #expect(preset.moveFiles == false)
    }
    
    @Test("Preset encodes and decodes correctly")
    func testPresetCodable() async throws {
        let steps = [
            RenamingStep(type: .prefix("pre_")),
            RenamingStep(type: .suffix("_suf"))
        ]
        let originalPreset = Preset(
            name: "My Preset",
            renamingSteps: steps,
            overwrite: true,
            moveFiles: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalPreset)
        
        let decoder = JSONDecoder()
        let decodedPreset = try decoder.decode(Preset.self, from: data)
        
        #expect(decodedPreset.id == originalPreset.id)
        #expect(decodedPreset.name == originalPreset.name)
        #expect(decodedPreset.renamingSteps.count == 2)
        #expect(decodedPreset.overwrite == true)
        #expect(decodedPreset.moveFiles == true)
    }
}

// MARK: - SelectedFile Tests

struct SelectedFileTests {
    
    @Test("SelectedFile initializes with correct values")
    func testSelectedFileInitialization() async throws {
        let bookmarkData = "test".data(using: .utf8)!
        let file = SelectedFile(fileName: "test.txt", bookmark: bookmarkData)
        
        #expect(file.fileName == "test.txt")
        #expect(file.bookmark == bookmarkData)
    }
    
    @Test("SelectedFile encodes and decodes correctly")
    func testSelectedFileCodable() async throws {
        let bookmarkData = "bookmark data".data(using: .utf8)!
        let originalFile = SelectedFile(fileName: "document.pdf", bookmark: bookmarkData)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalFile)
        
        let decoder = JSONDecoder()
        let decodedFile = try decoder.decode(SelectedFile.self, from: data)
        
        #expect(decodedFile.id == originalFile.id)
        #expect(decodedFile.fileName == originalFile.fileName)
        #expect(decodedFile.bookmark == originalFile.bookmark)
    }
}

// MARK: - ThumbnailSize Tests

struct ThumbnailSizeTests {
    
    @Test("ThumbnailSize small has correct dimensions")
    func testSmallSize() async throws {
        let size = ThumbnailSize.small
        #expect(size.size.width == 24)
        #expect(size.size.height == 24)
        #expect(size.systemImage == "square.resize.down")
    }
    
    @Test("ThumbnailSize large has correct dimensions")
    func testLargeSize() async throws {
        let size = ThumbnailSize.large
        #expect(size.size.width == 128)
        #expect(size.size.height == 128)
        #expect(size.systemImage == "square.resize.up")
    }
}

// MARK: - FileFormat Tests

struct FileFormatTests {
    
    @Test("FileFormat displayName returns correct values")
    func testDisplayNames() async throws {
        #expect(FileFormat.none.displayName == "None")
        #expect(FileFormat.hyphenated.displayName == "lowercase-hyphenated")
        #expect(FileFormat.camelCased.displayName == "camelCase")
        #expect(FileFormat.lowercaseUnderscored.displayName == "snake_case")
    }
}

// MARK: - UIStateViewModel Tests

@MainActor
struct UIStateViewModelTests {
    
    @Test("UIStateViewModel initializes with correct defaults")
    func testInitialState() async throws {
        let vm = UIStateViewModel()
        
        #expect(vm.showToast == false)
        #expect(vm.toastMessage == "")
        #expect(vm.toastIsError == false)
        #expect(vm.showInspector == true)
        #expect(vm.showSavePresetDialog == false)
        #expect(vm.showPresetManagementDialog == false)
        #expect(vm.newPresetName == "")
        #expect(vm.presetActionError == "")
        #expect(vm.fileNeedingBookmarkRefresh == nil)
    }
    
    @Test("UIStateViewModel showToastMessage sets values correctly")
    func testShowToastMessage() async throws {
        let vm = UIStateViewModel()
        
        vm.showToastMessage("Test message", isError: false)
        
        #expect(vm.toastMessage == "Test message")
        #expect(vm.toastIsError == false)
        #expect(vm.showToast == true)
    }
    
    @Test("UIStateViewModel showToastMessage with error flag")
    func testShowToastMessageError() async throws {
        let vm = UIStateViewModel()
        
        vm.showToastMessage("Error occurred", isError: true)
        
        #expect(vm.toastMessage == "Error occurred")
        #expect(vm.toastIsError == true)
        #expect(vm.showToast == true)
    }
    
    @Test("UIStateViewModel dismissToast hides toast")
    func testDismissToast() async throws {
        let vm = UIStateViewModel()
        
        vm.showToastMessage("Test", isError: false)
        #expect(vm.showToast == true)
        
        vm.dismissToast()
        #expect(vm.showToast == false)
    }
    
    @Test("UIStateViewModel toggleInspector toggles state")
    func testToggleInspector() async throws {
        let vm = UIStateViewModel()
        
        #expect(vm.showInspector == true)
        vm.toggleInspector()
        #expect(vm.showInspector == false)
        vm.toggleInspector()
        #expect(vm.showInspector == true)
    }
    
    @Test("UIStateViewModel resetDialogState clears form state")
    func testResetDialogState() async throws {
        let vm = UIStateViewModel()
        
        vm.newPresetName = "Test Preset"
        vm.presetActionError = "Some error"
        vm.showSavePresetDialog = true
        vm.showPresetManagementDialog = true
        
        vm.resetDialogState()
        
        #expect(vm.newPresetName == "")
        #expect(vm.presetActionError == "")
        #expect(vm.showSavePresetDialog == false)
        #expect(vm.showPresetManagementDialog == false)
    }
}

// MARK: - FileProcessingViewModel Tests

@MainActor
struct FileProcessingViewModelTests {
    
    /// Creates an isolated ViewModel with its own UserDefaults instance for hermetic testing
    private func createIsolatedViewModel() -> FileProcessingViewModel {
        let testDefaults = UserDefaults(suiteName: "com.scrubby.tests.\(UUID().uuidString)")!
        let persistenceService = BookmarkPersistenceService(userDefaults: testDefaults, key: "testBookmarks")
        return FileProcessingViewModel(persistenceService: persistenceService)
    }
    
    @Test("FileProcessingViewModel initializes with correct defaults")
    func testInitialState() async throws {
        let vm = createIsolatedViewModel()
        
        #expect(vm.overwrite == false)
        #expect(vm.moveFiles == false)
        #expect(vm.destinationFolderURL == nil)
        #expect(vm.renamingSteps.count == 1) // Default step
        #expect(vm.selectedFiles.isEmpty) // No files in isolated storage
    }
    
    @Test("FileProcessingViewModel clearFiles removes all files")
    func testClearFiles() async throws {
        let vm = createIsolatedViewModel()
        
        // Seed with mock files by directly setting the property
        let bookmarkData = "test".data(using: .utf8)!
        vm.selectedFiles = [
            SelectedFile(fileName: "file1.txt", bookmark: bookmarkData),
            SelectedFile(fileName: "file2.txt", bookmark: bookmarkData)
        ]
        
        #expect(vm.selectedFiles.count == 2)
        
        vm.clearFiles()
        
        #expect(vm.selectedFiles.isEmpty)
    }
    
    @Test("FileProcessingViewModel applyPreset updates state")
    func testApplyPreset() async throws {
        let vm = createIsolatedViewModel()
        
        let steps = [
            RenamingStep(type: .prefix("test_")),
            RenamingStep(type: .suffix("_end"))
        ]
        let preset = Preset(
            name: "Test",
            renamingSteps: steps,
            overwrite: true,
            moveFiles: true
        )
        
        vm.applyPreset(preset)
        
        #expect(vm.renamingSteps.count == 2)
        #expect(vm.overwrite == true)
        #expect(vm.moveFiles == true)
    }
    
    @Test("FileProcessingViewModel createPreset captures current state")
    func testCreatePreset() async throws {
        let vm = createIsolatedViewModel()
        
        vm.renamingSteps = [RenamingStep(type: .prefix("pre_"))]
        vm.overwrite = true
        vm.moveFiles = false
        
        let preset = vm.createPreset(name: "My Preset")
        
        #expect(preset.name == "My Preset")
        #expect(preset.renamingSteps.count == 1)
        #expect(preset.overwrite == true)
        #expect(preset.moveFiles == false)
    }
    
    @Test("FileProcessingViewModel previewFileName uses RenamingEngine")
    func testPreviewFileName() async throws {
        let vm = createIsolatedViewModel()
        
        vm.renamingSteps = [RenamingStep(type: .prefix("2024_"))]
        
        let bookmarkData = "test".data(using: .utf8)!
        let file = SelectedFile(fileName: "document.txt", bookmark: bookmarkData)
        
        let preview = vm.previewFileName(for: file, at: 0)
        
        #expect(preview == "2024_document.txt")
    }
    
    @Test("FileProcessingViewModel previewFileName handles sequential numbering")
    func testPreviewFileNameSequential() async throws {
        let vm = createIsolatedViewModel()
        
        vm.renamingSteps = [RenamingStep(type: .sequentialNumbering(start: 1, minDigits: 3, position: .prefix))]
        
        let bookmarkData = "test".data(using: .utf8)!
        let file = SelectedFile(fileName: "photo.jpg", bookmark: bookmarkData)
        
        let preview0 = vm.previewFileName(for: file, at: 0)
        let preview1 = vm.previewFileName(for: file, at: 1)
        let preview2 = vm.previewFileName(for: file, at: 2)
        
        #expect(preview0 == "001photo.jpg")
        #expect(preview1 == "002photo.jpg")
        #expect(preview2 == "003photo.jpg")
    }
    
    @Test("FileProcessingViewModel removeFile removes correct file by ID")
    func testRemoveFile() async throws {
        let vm = createIsolatedViewModel()
        
        let bookmarkData = "test".data(using: .utf8)!
        let file1 = SelectedFile(fileName: "file1.txt", bookmark: bookmarkData)
        let file2 = SelectedFile(fileName: "file2.txt", bookmark: bookmarkData)
        let file3 = SelectedFile(fileName: "file3.txt", bookmark: bookmarkData)
        
        vm.selectedFiles = [file1, file2, file3]
        
        vm.removeFile(id: file2.id)
        
        #expect(vm.selectedFiles.count == 2)
        #expect(vm.selectedFiles.contains(where: { $0.id == file1.id }))
        #expect(!vm.selectedFiles.contains(where: { $0.id == file2.id }))
        #expect(vm.selectedFiles.contains(where: { $0.id == file3.id }))
    }
}

// MARK: - FileProcessingError Tests

struct FileProcessingErrorTests {
    
    @Test("FileProcessingError initializes with all properties")
    func testErrorInitialization() async throws {
        let fileId = UUID()
        let error = FileProcessingError(
            fileId: fileId,
            fileName: "test.txt",
            message: "Test error",
            kind: .staleBookmark
        )
        
        #expect(error.fileId == fileId)
        #expect(error.fileName == "test.txt")
        #expect(error.message == "Test error")
        #expect(error.kind == .staleBookmark)
    }
    
    @Test("FileProcessingError defaults to fileSystemError kind")
    func testErrorDefaultKind() async throws {
        let error = FileProcessingError(fileName: "test.txt", message: "Test error")
        
        #expect(error.kind == .fileSystemError)
        #expect(error.fileId == nil)
    }
    
    @Test("FileProcessingResult staleBookmarkFileIds returns correct IDs")
    func testStaleBookmarkFileIds() async throws {
        let staleId1 = UUID()
        let staleId2 = UUID()
        let otherId = UUID()
        
        let result = FileProcessingResult(
            successCount: 2,
            errorCount: 3,
            errors: [
                FileProcessingError(fileId: staleId1, fileName: "stale1.txt", message: "Stale", kind: .staleBookmark),
                FileProcessingError(fileId: otherId, fileName: "other.txt", message: "Failed", kind: .resolutionFailed),
                FileProcessingError(fileId: staleId2, fileName: "stale2.txt", message: "Stale", kind: .staleBookmark)
            ]
        )
        
        let staleIds = result.staleBookmarkFileIds
        
        #expect(staleIds.count == 2)
        #expect(staleIds.contains(staleId1))
        #expect(staleIds.contains(staleId2))
        #expect(!staleIds.contains(otherId))
    }
    
    @Test("FileProcessingResult firstStaleBookmarkFileId returns first stale ID")
    func testFirstStaleBookmarkFileId() async throws {
        let staleId = UUID()
        
        let result = FileProcessingResult(
            successCount: 1,
            errorCount: 2,
            errors: [
                FileProcessingError(fileId: UUID(), fileName: "other.txt", message: "Failed", kind: .fileSystemError),
                FileProcessingError(fileId: staleId, fileName: "stale.txt", message: "Stale", kind: .staleBookmark)
            ]
        )
        
        #expect(result.firstStaleBookmarkFileId == staleId)
    }
    
    @Test("FileProcessingResult firstStaleBookmarkFileId returns nil when no stale errors")
    func testFirstStaleBookmarkFileIdNil() async throws {
        let result = FileProcessingResult(
            successCount: 1,
            errorCount: 1,
            errors: [
                FileProcessingError(fileId: UUID(), fileName: "other.txt", message: "Failed", kind: .fileSystemError)
            ]
        )
        
        #expect(result.firstStaleBookmarkFileId == nil)
    }
}
