//
//  LoadingOverlayView.swift
//  Disk Visualizer
//
//  The "Scanning…" overlay: concentric pulsing rings, a rotating radar sweep,
//  a glowing center dot, and an indeterminate shimmer bar.
//

import SwiftUI

struct LoadingOverlayView: View {
    @Environment(\.theme) private var theme
    let name: String

    @State private var spin = false
    @State private var pulse = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            theme.overlayBg.ignoresSafeArea()

            VStack(spacing: 26) {
                radar
                VStack(spacing: 4) {
                    Text("Scanning \(name)…")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.scanText)
                    Text("Indexing files and calculating sizes")
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.scanSub)
                }
                shimmerBar
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: false)) { shimmer = true }
        }
    }

    private var radar: some View {
        ZStack {
            ring(size: 184, delay: 0)
            ring(size: 128, delay: 0.3)
            ring(size: 72, delay: 0.6)

            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: theme.accent.opacity(0), location: 0),
                            .init(color: theme.accent.opacity(0.5), location: 0.15),
                            .init(color: theme.accent.opacity(0), location: 0.25),
                            .init(color: theme.accent.opacity(0), location: 1),
                        ]),
                        center: .center
                    )
                )
                .frame(width: 184, height: 184)
                .rotationEffect(.degrees(spin ? 360 : 0))

            Circle()
                .fill(theme.accent)
                .frame(width: 9, height: 9)
                .shadow(color: theme.accent.opacity(0.65), radius: 8)
        }
        .frame(width: 184, height: 184)
    }

    private func ring(size: CGFloat, delay: Double) -> some View {
        Circle()
            .strokeBorder(theme.scanRing, lineWidth: 1)
            .frame(width: size, height: size)
            .opacity(pulse ? 0.6 : 0.22)
            .animation(
                .easeInOut(duration: 2).repeatForever(autoreverses: true).delay(delay),
                value: pulse
            )
    }

    private var shimmerBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            Capsule().fill(theme.scanTrack)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.accent.opacity(0), theme.accent, theme.accent.opacity(0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: width * 0.42)
                        .offset(x: shimmer ? width : -width * 0.42)
                }
                .clipShape(Capsule())
        }
        .frame(width: 224, height: 4)
    }
}
