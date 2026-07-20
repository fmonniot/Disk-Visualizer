//
//  TreemapLayout.swift
//  Disk Visualizer
//
//  Squarified treemap layout, ported from the design's `squarify()`. Produces
//  tiles that pack the given rectangle with aspect ratios close to 1.
//

import CoreGraphics

struct TreemapTile: Identifiable {
    let node: FileNode
    let rect: CGRect
    var id: FileNode.ID { node.id }
}

nonisolated enum TreemapLayout {
    static func tiles(for nodes: [FileNode], in size: CGSize) -> [TreemapTile] {
        let children = nodes.filter { $0.size > 0 }
        guard !children.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let total = children.reduce(0.0) { $0 + Double($1.size) }
        guard total > 0 else { return [] }

        let scale = Double(size.width) * Double(size.height) / total
        // `nodes` is already sorted by size descending (scan-time sort), so
        // scaling to area preserves order without a re-sort here.
        let items = children
            .map { (node: $0, area: Double($0.size) * scale) }

        var result: [TreemapTile] = []
        var (rx, ry) = (0.0, 0.0)
        var (rw, rh) = (Double(size.width), Double(size.height))
        var row: [(node: FileNode, area: Double)] = []

        func worst(_ candidate: [(node: FileNode, area: Double)], _ length: Double) -> Double {
            guard length > 0 else { return .infinity }
            var sum = 0.0, minA = Double.infinity, maxA = 0.0
            for item in candidate {
                sum += item.area
                minA = min(minA, item.area)
                maxA = max(maxA, item.area)
            }
            guard sum > 0 else { return .infinity }
            let s2 = sum * sum, l2 = length * length
            return max((l2 * maxA) / s2, s2 / (l2 * minA))
        }

        func layoutRow() {
            let sum = row.reduce(0.0) { $0 + $1.area }
            if rw >= rh {
                let colWidth = sum / rh
                var y = ry
                for item in row {
                    let h = item.area / colWidth
                    result.append(TreemapTile(node: item.node,
                                              rect: CGRect(x: rx, y: y, width: colWidth, height: h)))
                    y += h
                }
                rx += colWidth
                rw -= colWidth
            } else {
                let rowHeight = sum / rw
                var x = rx
                for item in row {
                    let w = item.area / rowHeight
                    result.append(TreemapTile(node: item.node,
                                              rect: CGRect(x: x, y: ry, width: w, height: rowHeight)))
                    x += w
                }
                ry += rowHeight
                rh -= rowHeight
            }
            row.removeAll(keepingCapacity: true)
        }

        var index = 0
        while index < items.count {
            let item = items[index]
            let length = max(min(rw, rh), 1)
            if row.isEmpty {
                row.append(item)
                index += 1
            } else if worst(row, length) >= worst(row + [item], length) {
                row.append(item)
                index += 1
            } else {
                layoutRow()
            }
        }
        if !row.isEmpty { layoutRow() }

        return result
    }
}
