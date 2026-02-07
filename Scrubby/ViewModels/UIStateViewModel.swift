import Foundation
import SwiftUI

/// ViewModel managing pure UI state (dialogs, toasts, preferences)
@MainActor
class UIStateViewModel: ObservableObject {
    
    // MARK: - Dialog State
    
    @Published var isFileImporterPresented: Bool = false
    @Published var isAdditionalFileImporterPresented: Bool = false
    @Published var isFolderImporterPresented: Bool = false
    @Published var showSavePresetDialog: Bool = false
    @Published var showPresetManagementDialog: Bool = false
    @Published var showInspector: Bool = true
    
    // MARK: - Toast State
    
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var toastIsError: Bool = false
    
    // MARK: - Form State
    
    @Published var newPresetName: String = ""
    @Published var presetActionError: String = ""
    @Published var thumbnailSizePreference: ThumbnailSize = .small
    @Published var fileNeedingBookmarkRefresh: SelectedFile? = nil
    
    // MARK: - Public Methods
    
    /// Shows a toast message
    /// - Parameters:
    ///   - message: The message to display
    ///   - isError: Whether this is an error message
    func showToastMessage(_ message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        withAnimation {
            showToast = true
        }
        
        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation {
                self.showToast = false
            }
        }
    }
    
    /// Manually dismisses the toast
    func dismissToast() {
        withAnimation {
            showToast = false
        }
    }
    
    /// Toggles inspector visibility
    func toggleInspector() {
        showInspector.toggle()
    }
    
    /// Resets dialog-related state
    func resetDialogState() {
        newPresetName = ""
        presetActionError = ""
        showSavePresetDialog = false
        showPresetManagementDialog = false
    }
}
