//
//  RenamingStepsListView.swift
//  FileScrubby
//
//  Created by Ryan Graves on 6/10/25.
//


import SwiftUI

// MARK: - RenamingStepsListView
struct RenamingStepsListView: View {
    @Binding var renamingSteps: [RenamingStep]
    @State private var draggingStep: RenamingStep?

    var body: some View {
        VStack(spacing: 8) {
            ForEach($renamingSteps) { $step in
                RenamingStepRow(
                    step: $step,
                    draggingStep: $draggingStep,
                    removeAction: {
                        if let index = renamingSteps.firstIndex(where: { $0.id == step.id }) {
                            renamingSteps.remove(at: index)
                        }
                    }
                )
                .onDrag {
                    self.draggingStep = step
                    return NSItemProvider(object: step.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: StepDropDelegate(item: step, steps: $renamingSteps, current: $draggingStep))
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
        }
        .listStyle(.plain)
        .onChange(of: draggingStep) { oldValue, newValue in
            // If a drag is active, schedule a reset after 2 seconds.
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if draggingStep != nil {
                        draggingStep = nil
                        print("DEBUG: Dragging state reset after timeout")
                    }
                }
            }
        }
    }
}
