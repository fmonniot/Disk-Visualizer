//
//  SharedComponents.swift
//  Disk Visualizer
//
//  Small reusable pieces shared across the panes.
//

import SwiftUI

/// A rounded/circular swatch filled with a category's gradient.
struct GradientSwatch: View {
    let category: FileCategory
    var size: CGFloat = 9
    /// `nil` renders a circle (used for files); a value renders a rounded rect.
    var cornerRadius: CGFloat? = 3

    var body: some View {
        Group {
            if let cornerRadius {
                RoundedRectangle(cornerRadius: cornerRadius).fill(category.swatchGradient)
            } else {
                Circle().fill(category.swatchGradient)
            }
        }
        .frame(width: size, height: size)
    }
}

extension View {
    /// The uppercase, letter-spaced section header used above each column.
    func sectionHeader(_ theme: Theme) -> some View {
        self
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(theme.label)
    }
}
