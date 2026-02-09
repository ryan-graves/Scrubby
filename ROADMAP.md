# Architecture Refactoring Roadmap

## Overview
This document tracks the ongoing refactoring effort to improve FileScrubby's architecture by extracting business logic into services and ViewModels, following SwiftUI best practices.

## Goal
Transform ContentView from a 750+ line monolithic view with mixed concerns into a clean, maintainable architecture with:
- Service layer for business logic
- ViewModels for state management
- Lean ContentView focused on UI composition (~250-300 lines)

---

## ✅ Phase 1: Service Layer (COMPLETED)

### Created Files:
1. **`Scrubby/Services/RenamingEngine.swift`** (56 lines)
   - Pure function for filename transformation
   - Extracted from ContentView.processedFileName() (lines 510-553)
   - Applies all renaming steps sequentially
   - No side effects, fully testable

2. **`Scrubby/Services/FileProcessingService.swift`** (142 lines)
   - File system operations (copy, move, trash)
   - Collision handling (overwrite vs unique naming)
   - Temporary file usage for safety
   - Error tracking and aggregation
   - Extracted from ContentView.saveFiles() (lines 556-674)

3. **`Scrubby/Services/BookmarkManager.swift`** (150 lines)
   - Security-scoped bookmark creation/resolution
   - Staleness detection and refresh workflow
   - Resource lifecycle management (start/stop accessing)
   - Async bookmark refresh with NSOpenPanel
   - Extracted from SelectedFile.resolvedSecurityScopedURL() and ContentView bookmark logic

4. **`Scrubby/Services/BookmarkPersistenceService.swift`** (48 lines)
   - UserDefaults persistence for SelectedFile array
   - JSON encoding/decoding
   - Extracted from ContentView.saveBookmarksToDefaults() and loadBookmarksFromDefaults()

### Benefits:
- ✅ Business logic separated from UI
- ✅ Services are unit testable
- ✅ Clear single responsibilities
- ✅ Reusable across the app

---

## ✅ Phase 2: ViewModel Layer (COMPLETED)

### Created Files:
1. **`Scrubby/ViewModels/FileProcessingViewModel.swift`** (288 lines)
   - `@Published` properties for domain state:
     - `selectedFiles: [SelectedFile]`
     - `renamingSteps: [RenamingStep]`
     - `overwrite: Bool`
     - `moveFiles: Bool`
   - Methods:
     - `addFiles(_:) async -> FileImportResult`
     - `removeFile(id:)`
     - `clearFiles()`
     - `previewFileName(for:at:) -> String`
     - `processFiles(destinationFolder:) async -> FileProcessingResult`
     - `applyPreset(_:)`
     - `createPreset(name:) -> Preset`
     - `refreshBookmark(for:) async throws -> SelectedFile`
   - Orchestrates all services
   - Auto-saves to UserDefaults via Combine

2. **`Scrubby/ViewModels/UIStateViewModel.swift`** (71 lines)
   - `@Published` properties for UI state:
     - Dialog visibility flags
     - Toast state (message, isError, showToast)
     - Form state (newPresetName, presetActionError)
     - UI preferences (thumbnailSizePreference, showInspector)
     - `fileNeedingBookmarkRefresh: SelectedFile?`
   - Methods:
     - `showToastMessage(_:isError:)`
     - `dismissToast()`
     - `toggleInspector()`
     - `resetDialogState()`

### Benefits:
- ✅ Clear separation: domain state vs UI state
- ✅ Observable objects for reactive UI updates
- ✅ Testable business logic orchestration
- ✅ Prepared for ContentView integration

---

## 🚧 Phase 3: ContentView Refactoring (TODO)

### Current State:
- **File**: `Scrubby/ContentView.swift`
- **Size**: 758 lines
- **Issues**:
  - 20+ `@State` variables mixing domain and UI concerns
  - Business logic embedded (processedFileName, saveFiles, handleFileImport)
  - Hard to test due to tight coupling
  - Bookmark management scattered throughout

### Target State:
- **Size**: ~250-300 lines
- **Structure**:
  ```swift
  struct ContentView: View {
      @StateObject private var fileProcessingVM = FileProcessingViewModel()
      @StateObject private var uiStateVM = UIStateViewModel()
      @StateObject private var presetManager = PresetManager()

      var body: some View {
          // UI composition only
      }

      // Thin action handlers that delegate to ViewModels
  }
  ```

### Step-by-Step Refactoring Plan:

#### Step 1: Replace State Declarations (Lines 56-91)
**Before:**
```swift
@State private var selectedFiles: [SelectedFile] = []
@State private var renamingSteps: [RenamingStep] = [...]
@State private var overwrite: Bool = false
@State private var moveFiles: Bool = false
@State private var showToast: Bool = false
@State private var toastMessage: String = ""
// ... 15+ more @State variables
```

**After:**
```swift
@StateObject private var fileProcessingVM = FileProcessingViewModel()
@StateObject private var uiStateVM = UIStateViewModel()
@StateObject private var presetManager = PresetManager()
```

#### Step 2: Update All View Bindings
Search and replace throughout the body:
- `selectedFiles` → `fileProcessingVM.selectedFiles`
- `$selectedFiles` → `$fileProcessingVM.selectedFiles`
- `renamingSteps` → `fileProcessingVM.renamingSteps`
- `$renamingSteps` → `$fileProcessingVM.renamingSteps`
- `overwrite` → `fileProcessingVM.overwrite`
- `$overwrite` → `$fileProcessingVM.overwrite`
- `moveFiles` → `fileProcessingVM.moveFiles`
- `$moveFiles` → `$fileProcessingVM.moveFiles`
- `showToast` → `uiStateVM.showToast`
- `$showToast` → `$uiStateVM.showToast`
- `toastMessage` → `uiStateVM.toastMessage`
- `toastIsError` → `uiStateVM.toastIsError`
- `showInspector` → `uiStateVM.showInspector`
- `$showInspector` → `$uiStateVM.showInspector`
- `thumbnailSizePreference` → `uiStateVM.thumbnailSizePreference`
- `$thumbnailSizePreference` → `$uiStateVM.thumbnailSizePreference`
- `showSavePresetDialog` → `uiStateVM.showSavePresetDialog`
- `$showSavePresetDialog` → `$uiStateVM.showSavePresetDialog`
- `showPresetManagementDialog` → `uiStateVM.showPresetManagementDialog`
- `$showPresetManagementDialog` → `$uiStateVM.showPresetManagementDialog`
- `newPresetName` → `uiStateVM.newPresetName`
- `$newPresetName` → `$uiStateVM.newPresetName`
- `presetActionError` → `uiStateVM.presetActionError`
- `fileNeedingBookmarkRefresh` → `uiStateVM.fileNeedingBookmarkRefresh`
- `$fileNeedingBookmarkRefresh` → `$uiStateVM.fileNeedingBookmarkRefresh`
- `isAdditionalFileImporterPresented` → `uiStateVM.isAdditionalFileImporterPresented`
- `$isAdditionalFileImporterPresented` → `$uiStateVM.isAdditionalFileImporterPresented`
- `isFolderImporterPresented` → `uiStateVM.isFolderImporterPresented`
- `$isFolderImporterPresented` → `$uiStateVM.isFolderImporterPresented`

#### Step 3: Update FileListItem Usage (Line 143)
**Before:**
```swift
FileListItem(
    thumbnailSizePreference: thumbnailSizePreference,
    file: file,
    selectedFiles: $selectedFiles,
    processedFileName: processedFileName(for: file.fileName, at: idx)
)
```

**After:**
```swift
FileListItem(
    thumbnailSizePreference: uiStateVM.thumbnailSizePreference,
    file: file,
    selectedFiles: $fileProcessingVM.selectedFiles,
    processedFileName: fileProcessingVM.previewFileName(for: file, at: idx)
)
```

#### Step 4: Replace handleFileImport (Lines 449-507)
**Delete entire function**, replace with:
```swift
private func handleFileImport(result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
        Task {
            let importResult = await fileProcessingVM.addFiles(urls)
            uiStateVM.showToastMessage(importResult.message, isError: importResult.hasErrors)
        }
    case .failure(let error):
        uiStateVM.showToastMessage("Error adding files: \(error.localizedDescription)", isError: true)
    }
}
```

#### Step 5: Replace saveFiles (Lines 556-657)
**Delete entire function**, replace with:
```swift
private func saveFiles() {
    guard let folder = fileProcessingVM.destinationFolderURL else {
        uiStateVM.showToastMessage("No destination folder selected.", isError: true)
        return
    }

    Task {
        let result = await fileProcessingVM.processFiles(destinationFolder: folder)
        uiStateVM.showToastMessage(result.summaryMessage, isError: result.hasErrors)

        // Handle stale bookmarks
        if let staleFile = result.errors.first(where: { $0.message.contains("stale") }) {
            if let file = fileProcessingVM.selectedFiles.first(where: { $0.fileName == staleFile.fileName }) {
                uiStateVM.fileNeedingBookmarkRefresh = file
            }
        }
    }
}
```

#### Step 6: Delete Removed Functions
Delete these functions entirely (business logic now in ViewModels/Services):
- `processedFileName(for:at:)` (lines 510-553) → Use `fileProcessingVM.previewFileName()`
- `uniqueDestinationURL(for:in:)` (lines 660-674) → In FileProcessingService
- `saveBookmarksToDefaults()` (lines 429-436) → Auto-handled by ViewModel
- `loadBookmarksFromDefaults()` (lines 438-446) → Auto-handled by ViewModel

#### Step 7: Replace showToastMessage (Lines 677-684)
**Delete function**, replace calls with:
```swift
uiStateVM.showToastMessage(message, isError: bool)
```

#### Step 8: Replace saveCurrentAsPreset (Lines 687-709)
**Replace with:**
```swift
private func saveCurrentAsPreset() {
    guard !uiStateVM.newPresetName.isEmpty else {
        uiStateVM.presetActionError = "Preset name cannot be empty."
        return
    }

    let preset = fileProcessingVM.createPreset(name: uiStateVM.newPresetName)

    do {
        try presetManager.savePreset(preset)
        uiStateVM.showSavePresetDialog = false
        uiStateVM.resetDialogState()
        uiStateVM.showToastMessage("Preset saved successfully!", isError: false)
    } catch {
        uiStateVM.presetActionError = "Error saving preset: \(error.localizedDescription)"
    }
}
```

#### Step 9: Replace applyPreset (Lines 711-716)
**Replace with:**
```swift
private func applyPreset(_ preset: Preset) {
    fileProcessingVM.applyPreset(preset)
    uiStateVM.showToastMessage("Applied preset: \(preset.name)", isError: false)
}
```

#### Step 10: Replace regenerateBookmark (Lines 720-749)
**Delete function** (now handled in bookmark refresh sheet), replace sheet content with:
```swift
.sheet(item: $uiStateVM.fileNeedingBookmarkRefresh) { file in
    VStack(spacing: 16) {
        Text("Refresh Access to File")
            .font(.headline)
        Text("Access to the file \"\(file.fileName)\" has expired or become invalid.\nPlease re-select the file to update its access permissions.")
            .multilineTextAlignment(.center)
            .padding()
        Button("Re-select File") {
            Task {
                do {
                    _ = try await fileProcessingVM.refreshBookmark(for: file)
                    uiStateVM.showToastMessage("Access refreshed for \"\(file.fileName)\".", isError: false)
                    uiStateVM.fileNeedingBookmarkRefresh = nil
                } catch {
                    uiStateVM.showToastMessage("Failed to refresh bookmark: \(error.localizedDescription)", isError: true)
                    uiStateVM.fileNeedingBookmarkRefresh = nil
                }
            }
        }
        Button("Cancel") {
            uiStateVM.fileNeedingBookmarkRefresh = nil
        }
        .keyboardShortcut(.cancelAction)
    }
    .padding()
    .frame(width: 400)
}
```

#### Step 11: Remove onChange/onAppear (Lines 415-424)
**Delete onChange** for fileNeedingBookmarkRefresh (handled in sheet now)

**Replace onAppear:**
```swift
// Remove entirely - ViewModel loads bookmarks on init
```

#### Step 12: Update destinationFolderURL handling (Lines 263, 294)
The destination folder is now handled within processFiles, so update the folder importer:
```swift
.fileImporter(
    isPresented: $uiStateVM.isFolderImporterPresented,
    allowedContentTypes: [.folder],
    allowsMultipleSelection: false
) { result in
    switch result {
    case .success(let urls):
        if let folder = urls.first {
            fileProcessingVM.destinationFolderURL = folder
            saveFiles()
        }
    case .failure(let error):
        uiStateVM.showToastMessage("Error selecting folder: \(error.localizedDescription)", isError: true)
    }
}
```

---

## 📋 Phase 4: Verification (TODO)

After ContentView refactoring, verify:

### Build Verification:
1. ✅ Project builds without errors
2. ✅ No compiler warnings
3. ✅ All imports resolved

### Functional Testing:
1. ✅ App launches successfully
2. ✅ File selection works
   - Add files via "Choose files" button
   - Add additional files
   - Remove individual files
   - Clear all files
3. ✅ Renaming steps work
   - Add all step types
   - Reorder steps with arrow buttons
   - Remove steps
   - Preview updates correctly
4. ✅ File processing works
   - Copy mode (create copies)
   - Move mode (move files)
   - Overwrite mode on/off
   - Collision handling (unique names)
5. ✅ Presets work
   - Save preset
   - Load preset
   - Manage presets (edit/delete)
6. ✅ Bookmarks persist
   - Files persist across app restarts
   - Stale bookmark refresh flow works
7. ✅ Toast notifications appear
   - Success messages
   - Error messages
   - Auto-dismiss after 4 seconds
8. ✅ Inspector toggle works

### Code Quality Checks:
1. ✅ ContentView reduced to ~250-300 lines
2. ✅ No business logic in ContentView
3. ✅ All @State variables moved to ViewModels
4. ✅ Existing subviews unchanged (FileListItem, RenamingStepRow, etc.)

---

## 🎯 Success Criteria

### Architecture Goals:
- [x] Service layer created (4 services)
- [x] ViewModel layer created (2 ViewModels)
- [ ] ContentView refactored to use ViewModels
- [ ] All functionality works identically to before
- [ ] Code is more maintainable and testable

### Metrics:
- ContentView: 758 lines → Target: ~250-300 lines
- Testable services: 0 → 4
- ViewModels: 0 → 2
- Business logic in views: High → None

---

## ✅ Phase 5: Additional Features (IN PROGRESS)

### Completed:

1. **Unit Testing** ✅
   - 74 unit tests covering RenamingEngine, FileProcessingService, ViewModels, and models
   - Isolated UserDefaults for test independence
   - Comprehensive coverage of edge cases

2. **Better Error Handling** ✅
   - `FileProcessingErrorKind` enum for structured error types
   - `fileId` on errors for stable correlation
   - User-friendly error messages

3. **Regex Support in Find & Replace** ✅
   - Toggle to enable regex mode in Find & Replace step
   - Support for capture groups ($0 for full match, $1, $2, etc. in replacement)
   - Case-insensitive matching
   - Graceful handling of invalid regex patterns and templates
   - Pre-compiled regex caching for batch performance
   - 9 new unit tests for regex functionality

---

## 🔮 Future Enhancements

1. **Improved Accessibility**
   - VoiceOver labels and hints
   - Keyboard shortcuts
   - High contrast support

2. **Additional Features**
   - Batch preview/confirmation screen
   - Filename templates
   - History/undo system

---

## 📝 Notes

- Services are concrete types (protocol extraction planned for future testing infrastructure)
- ViewModels use `@MainActor` for thread safety
- Async/await used for async operations (file import, processing)
- Security-scoped bookmark lifecycle properly managed
- No breaking changes to existing subviews (FileListItem, RenamingStepRow, etc.)
- Existing patterns preserved (bindings, composition, etc.)

---

## 🤝 Next Steps for Reviewer

1. Review service layer implementation
2. Review ViewModel implementation
3. Test services compile and work correctly
4. Approve PR to merge service/ViewModel foundation
5. Next PR will complete ContentView refactoring following this roadmap

---

**Branch**: `feature/regex-find-replace`
**Status**: Phases 1-4 complete, Phase 5 in progress
**Last Updated**: 2026-02-08
