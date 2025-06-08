//
//  Preset.swift
//  Scrubby
//
//  Created on 6/1/25.
//

import Foundation
import SwiftUI

// MARK: - PresetManager
public class PresetManager: ObservableObject {
    @Published public var presets: [Preset] = []
    
    private let userDefaultsKey = "savedRenamerPresets"
    
    public init() {
        loadPresets()
    }
    
    public func savePreset(_ preset: Preset) throws {
        // Check for duplicate names
        if presets.contains(where: { $0.name.lowercased() == preset.name.lowercased() && $0.id != preset.id }) {
            throw PresetError.duplicateName
        }
        
        presets.append(preset)
        try persistPresets()
    }
    
    public func savePreset(name: String, renamingSteps: [RenamingStep], overwrite: Bool, moveFiles: Bool) -> Bool {
        // Don't allow duplicate preset names
        if presets.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            return false
        }
        
        let newPreset = Preset(
            name: name,
            renamingSteps: renamingSteps,
            overwrite: overwrite,
            moveFiles: moveFiles
        )
        
        presets.append(newPreset)
        do {
            try persistPresets()
            return true
        } catch {
            // Remove the preset we just added since saving failed
            presets.removeAll(where: { $0.id == newPreset.id })
            return false
        }
    }
    
    public func deletePreset(_ preset: Preset) throws {
        presets.removeAll(where: { $0.id == preset.id })
        try persistPresets()
    }
    
    public func updatePreset(_ preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            do {
                try persistPresets()
            } catch {
                print("Error updating preset: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func persistPresets() throws {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(presets)
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        } catch {
            throw PresetError.savingFailed
        }
    }
    
    private func loadPresets() {
        if let presetData = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let decoder = JSONDecoder()
                presets = try decoder.decode([Preset].self, from: presetData)
            } catch {
                print("Error decoding presets: \(error.localizedDescription)")
                // If there was an error, reset the presets
                presets = []
            }
        }
    }
}
