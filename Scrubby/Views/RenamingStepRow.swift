//
//  RenamingStepRow.swift
//  FileScrubby
//
//  Created by Ryan Graves on 6/10/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct RenamingStepRow: View {
    @Binding var step: RenamingStep
    @Binding var draggingStep: RenamingStep?
    let removeAction: () -> Void
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Your row content:
            HStack {
                if isHovering {
                    Image(systemName: "arrow.up.and.down.square.fill")
                        .foregroundStyle(.tint)
                } else {
                    Image(systemName: "arrow.up.and.down.square.fill")
                        .foregroundStyle(.tertiary)
                }
                switch step.type {
                case .findReplace(let find, let replace):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Find & Replace").font(.headline)
                        HStack {
                            TextField("Find", text: Binding(
                                get: { find },
                                set: { newValue in
                                    step.type = .findReplace(find: newValue, replace: replace)
                                }
                            ))
                            .onDrop(of: [UTType.text], isTargeted: nil) { _ in false }
                            .padding(6)
                            .background(Color(NSColor.quaternarySystemFill))
                            .cornerRadius(6)
                            TextField("Replace", text: Binding(
                                get: { replace },
                                set: { newValue in
                                    step.type = .findReplace(find: find, replace: newValue)
                                }
                            ))
                            .onDrop(of: [UTType.text], isTargeted: nil) { _ in false }
                            .padding(6)
                            .background(Color(NSColor.quaternarySystemFill))
                            .cornerRadius(6)
                        }
                    }
                case .prefix(let value):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prefix").font(.headline)
                        TextField("Prefix", text: Binding(
                            get: { value },
                            set: { newValue in
                                step.type = .prefix(newValue)
                            }
                        ))
                        .padding(6)
                        .background(Color(NSColor.quaternarySystemFill))
                        .cornerRadius(6)
                    }
                    .onDrop(of: [UTType.text], isTargeted: nil) { _ in false }
                case .suffix(let value):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suffix").font(.headline)
                        TextField("Suffix", text: Binding(
                            get: { value },
                            set: { newValue in
                                step.type = .suffix(newValue)
                            }
                        ))
                        .padding(6)
                        .background(Color(NSColor.quaternarySystemFill))
                        .cornerRadius(6)
                    }
                    .onDrop(of: [UTType.text], isTargeted: nil) { _ in false }
                case .fileFormat(_):
                    HStack(alignment: .top, spacing: 16) {
                        Text("Format").font(.headline)
                        HStack {
                            Picker("Format", selection: Binding(
                                get: {
                                    if case let .fileFormat(currentFormat) = step.type {
                                        return currentFormat
                                    }
                                    return .none
                                },
                                set: { newValue in
                                    step.type = .fileFormat(newValue)
                                }
                            )) {
                                ForEach(FileFormat.allCases, id: \.self) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                            Spacer()
                        }
                        .padding(6)
                        .cornerRadius(6)
                    }
                    .onDrop(of: [UTType.text], isTargeted: nil) { _ in false }
                }
                Spacer(minLength: 0)
            }
            .textFieldStyle(.plain)
            .padding(.vertical, 8)
            .padding(.leading, 8)
            .padding(.trailing, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            if isHovering {
                Button(action: removeAction) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        // Set opacity to 0 if this step is currently being dragged.
        .opacity(draggingStep?.id == step.id ? 0 : 1)
        .onHover { hovering in
            withAnimation { isHovering = hovering }
        }
    }
}

