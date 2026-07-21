//  RenamingStepsListView.swift
//  FileScrubby
//
//  Created by Ryan Graves on 6/10/25.
//


import SwiftUI

// MARK: - RenamingStepsListView
struct RenamingStepsListView: View {
    @Binding var renamingSteps: [RenamingStep]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach($renamingSteps) { $step in
                    RenamingStepRow(
                        step: $step,
                        moveUpAction: { moveStepUp(step) },
                        moveDownAction: { moveStepDown(step) },
                        removeAction: {
                            if let index = renamingSteps.firstIndex(where: { $0.id == step.id }) {
                                renamingSteps.remove(at: index)
                            }
                        },
                        isOnlyStep: renamingSteps.count == 1
                    )
                }
            }
            .animation(.default, value: renamingSteps)
        }
    }

    private func moveStepUp(_ step: RenamingStep) {
        guard let index = renamingSteps.firstIndex(where: { $0.id == step.id }), index > 0 else { return }
        withAnimation {
            renamingSteps.swapAt(index, index - 1)
        }
    }

    private func moveStepDown(_ step: RenamingStep) {
        guard let index = renamingSteps.firstIndex(where: { $0.id == step.id }), index < renamingSteps.count - 1 else { return }
        withAnimation {
            renamingSteps.swapAt(index, index + 1)
        }
    }
}

