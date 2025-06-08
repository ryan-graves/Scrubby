//
//  PresetManagementView.swift
//  Scrubby
//
//  Created on 6/1/25.
//

import SwiftUI

struct PresetManagementView: View {
    @ObservedObject var presetManager: PresetManager
    @State private var selectedPreset: Preset?
    @State private var editMode = false
    @State private var editingName = ""
    @State private var confirmDelete = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Manage Presets")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            if presetManager.presets.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bookmark.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No saved presets")
                        .font(.title3)
                    Text("Save your renaming configurations as presets for quick access")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(presetManager.presets) { preset in
                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if editMode && selectedPreset?.id == preset.id {
                                            TextField("Preset name", text: $editingName)
                                                .textFieldStyle(.roundedBorder)
                                                .onSubmit {
                                                    saveEditedName()
                                                }
                                        } else {
                                            Text(preset.name)
                                                .fontWeight(selectedPreset?.id == preset.id ? .bold : .regular)
                                        }
                                        Text("\(preset.renamingSteps.count) steps")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedPreset?.id == preset.id {
                                        if editMode {
                                            Button("Save") {
                                                saveEditedName()
                                            }
                                            .buttonStyle(.borderless)
                                            .foregroundStyle(.blue)
                                            Button("Cancel") {
                                                editMode = false
                                            }
                                            .buttonStyle(.borderless)
                                            .foregroundStyle(.secondary)
                                        } else {
                                            Button("Rename") {
                                                startEditing(preset)
                                            }
                                            .buttonStyle(.borderless)
                                            .foregroundStyle(.blue)
                                            Button("Delete") {
                                                confirmDelete = true
                                            }
                                            .buttonStyle(.borderless)
                                            .foregroundStyle(.red)
                                        }
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedPreset?.id == preset.id ?
                                              Color.accentColor.opacity(0.1) :
                                                Color.clear)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    if !editMode {
                                        selectedPreset = preset
                                    }
                                }
                                .alert("Delete Preset?", isPresented: $confirmDelete) {
                                    Button("Cancel", role: .cancel) {}
                                    Button("Delete", role: .destructive) {
                                        if let preset = selectedPreset {
                                            deletePreset(preset)
                                        }
                                    }
                                } message: {
                                    Text("Are you sure you want to delete the preset '\(selectedPreset?.name ?? "")'? This action cannot be undone.")
                                }
                                HStack {
                                    Spacer()
                                    Divider()
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(4)
                }
                .scrollIndicators(.automatic)
                .background(Color(.windowBackgroundColor))
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 450, height: 350)
    }
    
    private func startEditing(_ preset: Preset) {
        editMode = true
        editingName = preset.name
    }
    
    private func saveEditedName() {
        guard let preset = selectedPreset else { return }
        guard !editingName.isEmpty else {
            errorMessage = "Preset name cannot be empty."
            return
        }
        
        // Check if name is already taken by another preset
        if presetManager.presets.contains(where: { $0.name.lowercased() == editingName.lowercased() && $0.id != preset.id }) {
            errorMessage = "A preset with this name already exists."
            return
        }
        
        let updatedPreset = Preset(
            id: preset.id,
            name: editingName,
            renamingSteps: preset.renamingSteps,
            overwrite: preset.overwrite,
            moveFiles: preset.moveFiles,
            createdAt: preset.createdAt
        )
        
        presetManager.updatePreset(updatedPreset)
        selectedPreset = updatedPreset
        editMode = false
        errorMessage = ""
    }
    
    private func deletePreset(_ preset: Preset) {
        do {
            try presetManager.deletePreset(preset)
            selectedPreset = nil
        } catch {
            print("Error deleting preset: \(error.localizedDescription)")
            errorMessage = "Failed to delete preset: \(error.localizedDescription)"
        }
    }
}

#Preview {
    PresetManagementView(presetManager: PresetManager())
}
