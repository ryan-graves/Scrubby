//
//  StepDropDelegate.swift
//  FileScrubby
//
//  Created by Ryan Graves on 6/10/25.
//

import SwiftUI

struct StepDropDelegate: DropDelegate {
    let item: RenamingStep
    @Binding var steps: [RenamingStep]
    @Binding var current: RenamingStep?

    func dropEntered(info: DropInfo) {
        guard let current = current, current != item,
              let fromIndex = steps.firstIndex(of: current),
              let toIndex = steps.firstIndex(of: item)
        else { return }

        if steps[toIndex] != current {
            withAnimation {
                steps.move(fromOffsets: IndexSet(integer: fromIndex),
                           toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }

    // Remove dropExited altogether.

    func performDrop(info: DropInfo) -> Bool {
        // Delay clearing slightly (0.3 seconds) so the drag preview fades.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.current = nil
        }
        return true
    }
}
