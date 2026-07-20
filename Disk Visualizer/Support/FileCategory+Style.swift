//
//  FileCategory+Style.swift
//  Disk Visualizer
//
//  SwiftUI color helpers for a `FileCategory`. Kept separate from the model so
//  the model stays free of UI dependencies.
//

import SwiftUI

extension FileCategory {
    var startColor: Color { Color(hex: startHex) }
    var endColor: Color { Color(hex: endHex) }

    /// The two-stop gradient used for swatches, arcs, and tiles (135°, matching
    /// the design's `linear-gradient(135deg, c0, c1)`).
    var swatchGradient: LinearGradient {
        LinearGradient(
            colors: [startColor, endColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
