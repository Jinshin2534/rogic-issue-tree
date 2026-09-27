import Foundation

/// ツリー ⇄ Markdown（見出し = トップイシュー、箇条書き = 1層目以降）
public enum MarkdownCodec {
    public static func export(_ document: IssueDocument) -> String {
        document.outline().map { export($0.tree) }.joined(separator: "\n\n") + "\n"
    }

    public static func export(_ tree: Tree) -> String {
        var lines = ["# " + format(tree.root)]
        func walk(_ node: Node, _ level: Int) {
            for child in node.children {
                lines.append(String(repeating: "  ", count: level) + "- " + format(child))
                walk(child, level + 1)
            }
        }
        if !tree.root.children.isEmpty { lines.append("") }
        walk(tree.root, 0)
        return lines.joined(separator: "\n")
    }

    private static func format(_ node: Node) -> String {
        let text = node.text.replacingOccurrences(of: "\n", with: " ")
        return node.isRed && !text.isEmpty ? "**\(text)**" : text
    }

    /// Markdown / インデント付きテキストからツリーを作る
    public static func parse(_ source: String) -> [Tree] {
        var segments: [(heading: Item?, items: [Item])] = []
        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.replacingOccurrences(of: "\t", with: "    ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if let heading = headingText(trimmed) {
                segments.append((Item(indent: 0, heading), []))
                continue
            }
            let indent = line.prefix { $0 == " " || $0 == "\u{3000}" }.count
            let item = Item(indent: indent, stripMarker(trimmed))
            if segments.isEmpty { segments.append((nil, [])) }
            segments[segments.count - 1].items.append(item)
        }

        return segments.map { heading, items in
            var nodes = build(items)
            let root: Node
            if let heading {
                root = Node(text: heading.text, isRed: heading.isRed, children: nodes)
            } else if nodes.count == 1 {
                root = nodes.removeFirst()
            } else {
                root = Node(children: nodes)
            }
            return Tree(root: root)
        }
    }

    private struct Item {
        var indent: Int
        var text: String
        var isRed: Bool

        init(indent: Int, _ raw: String) {
            self.indent = indent
            if raw.count >= 4, raw.hasPrefix("**"), raw.hasSuffix("**") {
                text = String(raw.dropFirst(2).dropLast(2))
                isRed = true
            } else {
                text = raw
                isRed = false
            }
        }
    }

    private static func headingText(_ line: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        let body = line.drop { $0 == "#" }
        guard body.first == " " else { return nil }
        return body.trimmingCharacters(in: .whitespaces)
    }

    private static func stripMarker(_ line: String) -> String {
        for marker in ["- ", "* ", "+ ", "・"] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        if let range = line.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        return line
    }

    private final class Box {
        let item: Item
        var children: [Box] = []
        init(_ item: Item) { self.item = item }
        var node: Node { Node(text: item.text, isRed: item.isRed, children: children.map(\.node)) }
    }

    private static func build(_ items: [Item]) -> [Node] {
        var roots: [Box] = []
        var stack: [Box] = []
        for item in items {
            let box = Box(item)
            while let last = stack.last, last.item.indent >= item.indent { stack.removeLast() }
            if let parent = stack.last { parent.children.append(box) } else { roots.append(box) }
            stack.append(box)
        }
        return roots.map(\.node)
    }
}
