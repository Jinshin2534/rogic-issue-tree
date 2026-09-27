import IssueTreeCore
import SwiftUI

// MARK: - 共通パーツ（画面表示と PNG 書き出しで共用）

struct NodeBox: View {
    var text: String
    var isRed: Bool
    var selected = false
    var showsText = true
    var placeholder: String? = "未入力"

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(selected ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .topLeading) {
                if showsText {
                    label
                        .font(Font(NodeMetrics.font))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, NodeMetrics.horizontalPadding)
                        .padding(.vertical, NodeMetrics.verticalPadding)
                }
            }
    }

    @ViewBuilder private var label: some View {
        if text.isEmpty {
            Text(placeholder ?? " ").foregroundStyle(.tertiary)
        } else {
            Text(text).foregroundStyle(isRed ? AnyShapeStyle(Color.red) : AnyShapeStyle(.primary))
        }
    }
}

/// 列ヘッダーとカギ線
struct TreeBackdrop: View {
    let layout: TreeLayout
    var kind: TreeKind = .issue

    var body: some View {
        let config = layout.config
        ZStack(alignment: .topLeading) {
            ForEach(0..<layout.columnCount, id: \.self) { depth in
                Text(kind.header(depth: depth))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: config.nodeWidth, height: config.headerHeight)
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    .offset(x: config.columnX(depth), y: config.padding)
            }
            Path { path in
                let y = config.padding + config.headerHeight + 6
                path.move(to: CGPoint(x: config.padding, y: y))
                path.addLine(to: CGPoint(x: layout.size.width - config.padding, y: y))
            }
            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            connectors.stroke(Color.gray.opacity(0.7), lineWidth: 1.2)
        }
    }

    private var connectors: Path {
        Path { path in
            for (parentID, childIDs) in layout.children {
                guard let parent = layout.frames[parentID] else { continue }
                let midX = parent.maxX + layout.config.columnGap / 2
                let ys = childIDs.compactMap { layout.frames[$0]?.midY }
                guard let minY = ys.min(), let maxY = ys.max() else { continue }
                path.move(to: CGPoint(x: parent.maxX, y: parent.midY))
                path.addLine(to: CGPoint(x: midX, y: parent.midY))
                path.move(to: CGPoint(x: midX, y: min(minY, parent.midY)))
                path.addLine(to: CGPoint(x: midX, y: max(maxY, parent.midY)))
                for childID in childIDs {
                    guard let child = layout.frames[childID] else { continue }
                    path.move(to: CGPoint(x: midX, y: child.midY))
                    path.addLine(to: CGPoint(x: child.minX, y: child.midY))
                }
            }
        }
    }
}

// MARK: - 編集用キャンバス

struct TreeCanvasView: View {
    @ObservedObject var editor: EditorState
    let tree: Tree

    var body: some View {
        let layout = editor.layout(for: tree)
        GeometryReader { viewport in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editor.commitEdit()
                        }
                    TreeBackdrop(layout: layout, kind: tree.kind)
                    ForEach(tree.root.allNodes) { node in
                        if let frame = layout.frames[node.id] {
                            nodeView(node, depth: layout.depths[node.id] ?? 0)
                                .frame(width: frame.width, height: frame.height)
                                .offset(x: frame.minX, y: frame.minY)
                        }
                    }
                }
                // ツリーが画面より小さいときも左上に寄せる
                .frame(width: max(layout.size.width, viewport.size.width),
                       height: max(layout.size.height, viewport.size.height),
                       alignment: .topLeading)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background(KeyCatcher(isEditing: editor.editingID != nil, focusToken: editor.focusToken, onKey: editor.handleKey))
    }

    @ViewBuilder
    private func nodeView(_ node: Node, depth: Int) -> some View {
        let isEditing = editor.editingID == node.id
        let isSelected = editor.selectedID == node.id
        ZStack(alignment: .topTrailing) {
            if isEditing {
                NodeBox(text: node.text, isRed: node.isRed, selected: true, showsText: false)
                NodeTextEditor(editor: editor, nodeID: node.id, isRed: node.isRed)
            } else {
                NodeBox(text: node.text, isRed: node.isRed, selected: isSelected, placeholder: tree.kind.placeholder(depth: depth))
                    .contentShape(Rectangle())
                    .onTapGesture { editor.select(node.id) }
                    .simultaneousGesture(TapGesture(count: 2).onEnded { editor.beginEdit(node.id) })
            }
            if let drillID = node.drillTreeID, editor.file.doc.tree(drillID) != nil {
                Button {
                    editor.openTree(drillID)
                } label: {
                    Image(systemName: "arrow.down.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("深掘りしたツリーを開く (⌘↓)")
                .offset(x: 7, y: -7)
            }
        }
        .contextMenu {
            Button("深掘り") { editor.select(node.id); editor.drillDown() }
            if node.drillTreeID == nil {
                Menu("種類を選んで深掘り") {
                    ForEach(TreeKind.allCases, id: \.self) { kind in
                        Button(kind.title) { editor.select(node.id); editor.drillDown(kind: kind) }
                    }
                }
            }
            Button(node.isRed ? "赤字を解除" : "赤字にする") { editor.select(node.id); editor.toggleRed() }
            Divider()
            Button("子を追加") { editor.select(node.id); editor.addChild() }
            Button("削除", role: .destructive) { editor.select(node.id); editor.deleteSelected() }
                .disabled(node.id == tree.root.id)
        }
    }
}

// MARK: - PNG 書き出し用

struct StaticTreeView: View {
    let tree: Tree
    let layout: TreeLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            TreeBackdrop(layout: layout, kind: tree.kind)
            ForEach(tree.root.allNodes) { node in
                if let frame = layout.frames[node.id] {
                    NodeBox(text: node.text, isRed: node.isRed, placeholder: nil)
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)
                }
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }
}
