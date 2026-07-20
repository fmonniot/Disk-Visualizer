//
//  ToastView.swift
//  Disk Visualizer
//
//  Small transient confirmation pill shown near the bottom of the window.
//

import SwiftUI

struct ToastView: View {
    @Environment(\.theme) private var theme
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(theme.toastText)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.thickMaterial)
                    RoundedRectangle(cornerRadius: 12).fill(theme.toastBg.opacity(0.45))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.toastBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 22, y: 14)
    }
}
