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
    let moveUpAction: () -> Void
    let moveDownAction: () -> Void
    let removeAction: () -> Void
    let isOnlyStep: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack {
                if !isOnlyStep {
                    VStack {
                        Button(action: moveUpAction) {
                            Image(systemName: "arrow.up")
                                .foregroundStyle(isHovering ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.bordered)
                        .frame(width: 12)
                        Button(action: moveDownAction) {
                            Image(systemName: "arrow.down")
                                .foregroundStyle(isHovering ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.bordered)
                        .frame(width: 12)

                    }
                    .padding(8)
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
                case .replaceFilenameWith(let value):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rename").font(.headline)
                        TextField("New Name", text: Binding(
                            get: { value },
                            set: { newValue in
                                step.type = .replaceFilenameWith(newValue)
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
            .background(.ultraThinMaterial)
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
        .onHover { hovering in
            withAnimation { isHovering = hovering }
        }
    }
}

#Preview {
    struct RenamingStepRowPreviews: View {
        @State var findReplaceStep = RenamingStep(type: .findReplace(find: "FindText", replace: "ReplaceText"))
        @State var prefixStep = RenamingStep(type: .prefix("PRE_"))
        @State var suffixStep = RenamingStep(type: .suffix("_SUF"))
        @State var fileFormatStep = RenamingStep(type: .fileFormat(.camelCased))
        @State var draggingStep: RenamingStep? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                Text("Find & Replace Step").font(.title2)
                RenamingStepRow(
                    step: $findReplaceStep,
                    draggingStep: $draggingStep,
                    moveUpAction: {},
                    moveDownAction: {},
                    removeAction: {},
                    isOnlyStep: false
                )
                Text("Prefix Step").font(.title2)
                RenamingStepRow(
                    step: $prefixStep,
                    draggingStep: $draggingStep,
                    moveUpAction: {},
                    moveDownAction: {},
                    removeAction: {},
                    isOnlyStep: false
                )
                Text("Suffix Step").font(.title2)
                RenamingStepRow(
                    step: $suffixStep,
                    draggingStep: $draggingStep,
                    moveUpAction: {},
                    moveDownAction: {},
                    removeAction: {},
                    isOnlyStep: false
                )
                Text("File Format Step").font(.title2)
                RenamingStepRow(
                    step: $fileFormatStep,
                    draggingStep: $draggingStep,
                    moveUpAction: {},
                    moveDownAction: {},
                    removeAction: {},
                    isOnlyStep: false
                )
            }
            .padding()
            .frame(maxWidth: 500)
        }
    }
    return RenamingStepRowPreviews()
}
