//
//  Theme.swift
//  Disk Visualizer
//
//  Color roles for the whole UI, translated verbatim from the design's `dark`
//  and `light` palettes. The active theme follows the system appearance and is
//  passed down through the environment.
//

import SwiftUI

struct Theme {
    // Window background gradient stops (top -> bottom).
    var bg0: Color
    var bg1: Color
    var bg2: Color

    // Text & structure.
    var text: Color
    var border: Color
    var hair: Color
    var hair2: Color
    var label: Color
    var muted: Color
    var muted2: Color

    // Panels / bars.
    var panel: Color
    var panelBar: Color
    var bottomBar: Color

    // Details panel.
    var name: Color
    var kind: Color
    var value: Color
    var big: Color
    var path: Color

    // Search pill.
    var searchBg: Color
    var searchBorder: Color
    var searchText: Color

    // Reveal button.
    var btnBg: Color
    var btnBorder: Color
    var btnBgHover: Color

    // Sidebar tree.
    var treeText: Color
    var treeSize: Color
    var treeSel: Color
    var treeSelText: Color
    var treeCur: Color
    var treeHover: Color
    var disc: Color

    // Breadcrumbs.
    var crumbLast: Color
    var crumb: Color
    var crumbHover: Color
    var crumbSep: Color

    // Sunburst center label + arc separators.
    var labelName: Color
    var labelBig: Color
    var labelSub: Color
    var labelBack: Color
    var centerC0: Color
    var centerC1: Color
    var gap: Color

    // Treemap tiles.
    var tileHi: Color
    var tileSel: Color

    // Legend & view toggle.
    var legend: Color
    var toggleActiveBg: Color
    var toggleActiveText: Color
    var toggleText: Color

    // Scanning overlay.
    var overlayBg: Color
    var scanRing: Color
    var scanText: Color
    var scanSub: Color
    var scanTrack: Color
    var accent: Color

    // Tooltip.
    var tipBg: Color
    var tipBorder: Color
    var tipText: Color
    var tipSub: Color
    var tipVal: Color

    // Empty state.
    var emptyText: Color
    var emptyBorder: Color

    // Toast.
    var toastBg: Color
    var toastBorder: Color
    var toastText: Color

    /// Radial background matching `radial-gradient(140% 120% at 50% -10%, …)`.
    func backgroundGradient(diameter: CGFloat) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: bg0, location: 0),
                .init(color: bg1, location: 0.55),
                .init(color: bg2, location: 1),
            ]),
            center: UnitPoint(x: 0.5, y: -0.1),
            startRadius: 0,
            endRadius: diameter
        )
    }
}

extension Theme {
    static let dark = Theme(
        bg0: Color(hex: "17171d"), bg1: Color(hex: "0c0c10"), bg2: Color(hex: "08080b"),
        text: Color(hex: "e7e7ec"),
        border: .white.opacity(0.06), hair: .white.opacity(0.05), hair2: .white.opacity(0.04),
        label: Color(hex: "6a6a74"), muted: Color(hex: "6f6f79"), muted2: Color(hex: "8a8a94"),
        panel: .white.opacity(0.015), panelBar: .white.opacity(0.02), bottomBar: .white.opacity(0.025),
        name: Color(hex: "f0f0f5"), kind: Color(hex: "82828c"), value: Color(hex: "d2d2da"),
        big: Color(hex: "f2f2f7"), path: Color(hex: "b6b6c0"),
        searchBg: .white.opacity(0.05), searchBorder: .white.opacity(0.07), searchText: Color(hex: "6f6f79"),
        btnBg: .white.opacity(0.07), btnBorder: .white.opacity(0.1), btnBgHover: .white.opacity(0.13),
        treeText: Color(hex: "c9c9d1"), treeSize: Color(hex: "75757f"),
        treeSel: Color(hex: "786eff").opacity(0.22), treeSelText: Color(hex: "eef0ff"),
        treeCur: .white.opacity(0.05), treeHover: .white.opacity(0.06), disc: Color(hex: "8a8a94"),
        crumbLast: Color(hex: "e9e9f0"), crumb: Color(hex: "8c8c96"),
        crumbHover: Color(hex: "c7c7d0"), crumbSep: Color(hex: "55555f"),
        labelName: Color(hex: "c7c7cf"), labelBig: Color(hex: "f2f2f7"),
        labelSub: Color(hex: "7a7a84"), labelBack: Color(hex: "8b8b95"),
        centerC0: Color(hex: "21222b"), centerC1: Color(hex: "101117"), gap: Color(hex: "0b0c10"),
        tileHi: .white.opacity(0.15), tileSel: .white.opacity(0.92),
        legend: Color(hex: "a9a9b3"),
        toggleActiveBg: .white.opacity(0.15), toggleActiveText: .white, toggleText: Color(hex: "9a9aa4"),
        overlayBg: Color(hex: "08080b").opacity(0.94),
        scanRing: .white.opacity(0.08), scanText: Color(hex: "d8d8e0"),
        scanSub: Color(hex: "7a7a84"), scanTrack: .white.opacity(0.07), accent: Color(hex: "8a7bff"),
        tipBg: Color(hex: "1c1c22").opacity(0.85), tipBorder: .white.opacity(0.12),
        tipText: .white, tipSub: Color(hex: "b9b9c2"), tipVal: Color(hex: "e6e6ea"),
        emptyText: Color(hex: "6a6a74"), emptyBorder: .white.opacity(0.14),
        toastBg: Color(hex: "1e1e24").opacity(0.9), toastBorder: .white.opacity(0.12), toastText: Color(hex: "eaeaef")
    )

    static let light = Theme(
        bg0: Color(hex: "ffffff"), bg1: Color(hex: "f1f2f5"), bg2: Color(hex: "e8e9ee"),
        text: Color(hex: "1d1d22"),
        border: .black.opacity(0.09), hair: .black.opacity(0.07), hair2: .black.opacity(0.05),
        label: Color(hex: "8a8a92"), muted: Color(hex: "8a8a92"), muted2: Color(hex: "6f6f79"),
        panel: .black.opacity(0.02), panelBar: .black.opacity(0.015), bottomBar: .black.opacity(0.028),
        name: Color(hex: "18181d"), kind: Color(hex: "77777f"), value: Color(hex: "33333a"),
        big: Color(hex: "141419"), path: Color(hex: "4a4a54"),
        searchBg: .black.opacity(0.04), searchBorder: .black.opacity(0.08), searchText: Color(hex: "8a8a92"),
        btnBg: .black.opacity(0.05), btnBorder: .black.opacity(0.1), btnBgHover: .black.opacity(0.09),
        treeText: Color(hex: "3a3a42"), treeSize: Color(hex: "9a9aa2"),
        treeSel: Color(hex: "786eff").opacity(0.16), treeSelText: Color(hex: "2a2478"),
        treeCur: .black.opacity(0.045), treeHover: .black.opacity(0.055), disc: Color(hex: "9a9aa2"),
        crumbLast: Color(hex: "1d1d22"), crumb: Color(hex: "8a8a92"),
        crumbHover: Color(hex: "55555c"), crumbSep: Color(hex: "b5b5bc"),
        labelName: Color(hex: "55555c"), labelBig: Color(hex: "141419"),
        labelSub: Color(hex: "8a8a92"), labelBack: Color(hex: "8a8a92"),
        centerC0: Color(hex: "ffffff"), centerC1: Color(hex: "eceef2"), gap: Color(hex: "eef0f3"),
        tileHi: .white.opacity(0.22), tileSel: .white.opacity(0.95),
        legend: Color(hex: "6a6a72"),
        toggleActiveBg: .white, toggleActiveText: Color(hex: "18181d"), toggleText: Color(hex: "77777f"),
        overlayBg: Color(hex: "e8e9ee").opacity(0.94),
        scanRing: .black.opacity(0.08), scanText: Color(hex: "33333a"),
        scanSub: Color(hex: "8a8a92"), scanTrack: .black.opacity(0.07), accent: Color(hex: "8a7bff"),
        tipBg: Color(hex: "ffffff").opacity(0.92), tipBorder: .black.opacity(0.1),
        tipText: Color(hex: "18181d"), tipSub: Color(hex: "77777f"), tipVal: Color(hex: "33333a"),
        emptyText: Color(hex: "8a8a92"), emptyBorder: .black.opacity(0.14),
        toastBg: Color(hex: "ffffff").opacity(0.92), toastBorder: .black.opacity(0.1), toastText: Color(hex: "18181d")
    )
}

extension EnvironmentValues {
    @Entry var theme: Theme = .dark
}
