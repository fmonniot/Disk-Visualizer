//
//  ByteFormat.swift
//  Disk Visualizer
//
//  Byte- and date-formatting that mirror the design's `fmt()` / `fmtDate()`
//  helpers exactly, so the numbers read identically to the mockup.
//

import Foundation

enum ByteFormat {
    private static let tb: Double = 1_099_511_627_776
    private static let gb: Double = 1_073_741_824
    private static let mb: Double = 1_048_576
    private static let kb: Double = 1_024

    /// Formats a byte count like the design: e.g. "8.9 GB", "480 MB", "12 KB".
    static func string(_ bytes: Int64) -> String {
        let b = Double(bytes)
        if b >= tb { return String(format: "%.2f TB", b / tb) }
        if b >= gb {
            let decimals = b >= 10 * gb ? 0 : 1
            return String(format: "%.\(decimals)f GB", b / gb)
        }
        if b >= mb { return String(format: "%.0f MB", b / mb) }
        if b >= kb { return String(format: "%.0f KB", b / kb) }
        return "\(bytes) B"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// Formats a date like "Jul 19, 2026".
    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
