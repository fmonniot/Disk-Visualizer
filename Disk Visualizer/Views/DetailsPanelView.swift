//
//  DetailsPanelView.swift
//  Disk Visualizer
//
//  The right "Details" column: badge, size on disk, contents, modified date,
//  location, and the Reveal in Finder action.
//

import SwiftUI

struct DetailsPanelView: View {
    @Environment(VisualizerModel.self) private var model
    @Environment(\.theme) private var theme

    private var node: FileNode? { model.selection }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(theme.hair)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sizeSection
                    infoRow("Contents", contentsValue)
                    infoRow("Modified", node.map { ByteFormat.date($0.modified) } ?? "—")
                    whereSection
                }
                .padding(.horizontal, 18)
            }

            Divider().overlay(theme.border)
            revealButton
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
        }
        .frame(width: 310)
        .background(theme.panel)
        .overlay(alignment: .leading) {
            Rectangle().fill(theme.border).frame(width: 1)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details").sectionHeader(theme)
            HStack(spacing: 12) {
                badge
                VStack(alignment: .leading, spacing: 1) {
                    Text(node?.name ?? "—")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(kindLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.kind)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var badge: some View {
        RoundedRectangle(cornerRadius: 11)
            .fill((node?.category ?? .folder).swatchGradient)
            .frame(width: 40, height: 40)
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                    .blendMode(.plusLighter)
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
    }

    // MARK: - Sections

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Size on disk")
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
            Text(node.map { ByteFormat.string($0.size) } ?? "—")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.big)
            Text(percentLabel)
                .font(.system(size: 12))
                .foregroundStyle(theme.muted2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.hair2).frame(height: 1) }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(theme.muted)
            Spacer()
            Text(value).foregroundStyle(theme.value)
        }
        .font(.system(size: 12.5))
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.hair2).frame(height: 1) }
    }

    private var whereSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where")
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
            Text(node?.url.path(percentEncoded: false) ?? "—")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.path)
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
    }

    private var revealButton: some View {
        Button {
            if let node { model.reveal(node) }
        } label: {
            Text("Reveal in Finder")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(theme.btnBg, in: RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9).strokeBorder(theme.btnBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(node == nil)
    }

    // MARK: - Derived text

    private var kindLabel: String {
        guard let node else { return "—" }
        return node.isLeaf ? node.category.singularLabel : "Folder"
    }

    private var contentsValue: String {
        guard let node else { return "—" }
        return node.isLeaf ? "Single file" : "\(node.fileCount.formatted()) items"
    }

    private var percentLabel: String {
        guard let node else { return "" }
        guard let parent = node.parent else { return "Volume root" }
        let pct = node.fractionOfParent * 100
        return String(format: "%.1f%% of %@", pct, parent.name)
    }
}
