//
//  ToastView.swift
//  FileScrubby
//
//  Created by Ryan Graves on 6/10/25.
//

import SwiftUI

// MARK: - ToastView
struct ToastView: View {
    let message: String
    let isError: Bool
    @Binding var showToast: Bool
    
    var body: some View {
        HStack {
            Text(message)
            Button {
                withAnimation { showToast = false }
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .focusEffectDisabled()
            .frame(width: 16, height: 16)
        }
        .padding(.vertical, 8)
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .background(isError ? Color.red : Color.green)
        .foregroundColor(.white)
        .cornerRadius(8)
        .padding(.top, 10)
        .padding(8)
    }
}
