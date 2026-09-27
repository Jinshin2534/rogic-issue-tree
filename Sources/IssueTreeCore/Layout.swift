import CoreGraphics
import Foundation

public struct LayoutConfig: Sendable {
    public var nodeWidth: CGFloat = 240
    public var columnGap: CGFloat = 48
    public var rowGap: CGFloat = 10
    public var padding: CGFloat = 24
    public var headerHeight: CGFloat = 30
    public var headerGap: CGFloat = 20

    public init() {}

    public var contentTop: CGFloat { padding + headerHeight + headerGap }

    public func columnX(_ depth: Int) -> CGFloat {
        padding + CGFloat(depth) * (nodeWidth + columnGap)
    }
}

public enum Direction: Sendable {
    case up, down, left, right
}

public struct TreeLayout {
    public var config: LayoutConfig
    public var rootID: UUID
    public var frames: [UUID: CGRect] = [:]
    public var depths: [UUID: Int] = [:]
    public var parents: [UUID: UUID] = [:]
    /// 親ID → 子ID（表示順）
    public var children: [UUID: [UUID]] = [:]
    public var columnCount = 1
    public var size: CGSize = .zero

    public static func compute(root: Node, config: LayoutConfig = LayoutConfig(), height: (Node) -> CGFloat) -> TreeLayout {
        var layout = TreeLayout(config: config, rootID: root.id)
        var cursor = config.contentTop

        func shift(_ node: Node, by dy: CGFloat) {
            layout.frames[node.id]?.origin.y += dy
            node.children.forEach { shift($0, by: dy) }
        }

        func place(_ node: Node, depth: Int) {
            layout.depths[node.id] = depth
            layout.columnCount = max(layout.columnCount, depth + 1)
            let h = height(node)
            let x = config.columnX(depth)
            guard let firstChild = node.children.first, let lastChild = node.children.last else {
                layout.frames[node.id] = CGRect(x: x, y: cursor, width: config.nodeWidth, height: h)
                cursor += h + config.rowGap
                return
            }
            let start = cursor
            layout.children[node.id] = node.children.map(\.id)
            for child in node.children {
                layout.parents[child.id] = node.id
                place(child, depth: depth + 1)
            }
            let center = (layout.frames[firstChild.id]!.midY + layout.frames[lastChild.id]!.midY) / 2
            var y = center - h / 2
            if y < start {
                let dy = start - y
                node.children.forEach { shift($0, by: dy) }
                cursor += dy
                y = start
            }
            layout.frames[node.id] = CGRect(x: x, y: y, width: config.nodeWidth, height: h)
            cursor = max(cursor, y + h + config.rowGap)
        }

        place(root, depth: 0)
        let width = config.columnX(layout.columnCount - 1) + config.nodeWidth + config.padding
        layout.size = CGSize(width: width, height: cursor - config.rowGap + config.padding)
        return layout
    }

    /// 矢印キーでの移動先
    public func neighbor(of id: UUID, _ direction: Direction) -> UUID? {
        guard let frame = frames[id], let depth = depths[id] else { return nil }
        switch direction {
        case .left:
            return parents[id]
        case .right:
            return children[id]?.min { abs(frames[$0]!.midY - frame.midY) < abs(frames[$1]!.midY - frame.midY) }
        case .up, .down:
            let sameColumn = frames.filter { depths[$0.key] == depth && $0.key != id }
            let candidates = sameColumn.filter { direction == .up ? $0.value.midY < frame.midY : $0.value.midY > frame.midY }
            return candidates.min { abs($0.value.midY - frame.midY) < abs($1.value.midY - frame.midY) }?.key
        }
    }
}
