//
//  AnnularSector.swift
//  Disk Visualizer
//
//  A ring segment used for one sunburst arc. Angles are measured in radians
//  from the top (12 o'clock), increasing clockwise — matching the design's
//  `pt(r,a) = (cx + r·sin a, cy − r·cos a)`.
//

import SwiftUI

struct AnnularSector: Shape {
    var center: CGPoint
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var startAngle: Double
    var endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let span = endAngle - startAngle
        guard span > 0 else { return path }

        // ~2° chords keep the arcs smooth without addArc direction ambiguity.
        let steps = max(2, Int((span / (.pi / 90)).rounded(.up)))

        func point(_ radius: CGFloat, _ angle: Double) -> CGPoint {
            CGPoint(x: center.x + radius * sin(angle),
                    y: center.y - radius * cos(angle))
        }

        path.move(to: point(outerRadius, startAngle))
        for i in 1...steps {
            path.addLine(to: point(outerRadius, startAngle + span * Double(i) / Double(steps)))
        }
        path.addLine(to: point(innerRadius, endAngle))
        for i in 1...steps {
            path.addLine(to: point(innerRadius, endAngle - span * Double(i) / Double(steps)))
        }
        path.closeSubpath()
        return path
    }
}

/// One computed arc in the sunburst.
struct SunburstArc: Identifiable {
    let node: FileNode
    let depth: Int
    let startAngle: Double
    let endAngle: Double
    var id: FileNode.ID { node.id }
    var midAngle: Double { (startAngle + endAngle) / 2 }
}

enum SunburstLayout {
    static let center = CGPoint(x: 360, y: 360)
    static let innerRadius: CGFloat = 84      // R0
    static let ringWidth: CGFloat = 57        // ringW
    static let maxDepth = 4
    static let gap: CGFloat = 1.5
    static var totalRadius: CGFloat { innerRadius + CGFloat(maxDepth) * ringWidth }

    /// Computes the visible arcs for `current`, proportional to size.
    static func arcs(for current: FileNode) -> [SunburstArc] {
        var result: [SunburstArc] = []

        func recurse(_ node: FileNode, depth: Int, start: Double, end: Double) {
            if depth > maxDepth { return }
            if depth >= 1 {
                result.append(SunburstArc(node: node, depth: depth, startAngle: start, endAngle: end))
            }
            guard !node.children.isEmpty else { return }
            let total = Double(node.size)
            guard total > 0 else { return }

            var cursor = start
            for child in node.children.sorted(by: { $0.size > $1.size }) {
                let span = (end - start) * Double(child.size) / total
                recurse(child, depth: depth + 1, start: cursor, end: cursor + span)
                cursor += span
            }
        }

        recurse(current, depth: 0, start: 0, end: 2 * .pi)
        return result
    }
}
