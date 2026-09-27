import AppKit
import IssueTreeCore
import SwiftUI

enum NodeMetrics {
    static let font = NSFont.systemFont(ofSize: 13)
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 9
    static let minHeight: CGFloat = 38

    static func height(for text: String, width: CGFloat) -> CGFloat {
        let sample = text.isEmpty ? " " : text
        let bounds = (sample as NSString).boundingRect(
            with: CGSize(width: width - horizontalPadding * 2, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return max(minHeight, ceil(bounds.height) + verticalPadding * 2 + 2)
    }
}

/// ウィンドウごとの編集状態（表示中のツリー・選択・編集中ノード）と操作
@MainActor
final class EditorState: ObservableObject {
    let file: IssueTreeFile
    weak var undoManager: UndoManager?

    @Published var currentTreeID: UUID
    @Published var selectedID: UUID?
    @Published var editingID: UUID?
    @Published var draft = ""
    /// 入力開始のきっかけになったキー。テキストビュー生成後に再送して IME に渡す。
    var pendingKeyEvent: NSEvent?
    /// キャンバスにフォーカスを戻すための合図
    @Published var focusToken = 0

    let config = LayoutConfig()

    init(file: IssueTreeFile) {
        self.file = file
        currentTreeID = file.doc.trees[0].id
        selectedID = file.doc.trees[0].root.id
    }

    var currentTree: Tree {
        file.doc.tree(currentTreeID) ?? file.doc.trees[0]
    }

    func layout(for tree: Tree) -> TreeLayout {
        let width = config.nodeWidth
        return TreeLayout.compute(root: tree.root, config: config) { [editingID, draft] node in
            NodeMetrics.height(for: node.id == editingID ? draft : node.text, width: width)
        }
    }

    /// 取り消しなどでツリーやノードが消えた場合に状態を整える
    func validate() {
        if file.doc.tree(currentTreeID) == nil {
            currentTreeID = file.doc.trees[0].id
        }
        let tree = currentTree
        if let id = selectedID, tree.root.find(id) == nil {
            selectedID = tree.root.id
        }
        if let id = editingID, tree.root.find(id) == nil {
            editingID = nil
        }
    }

    private func mutate(_ change: (inout IssueDocument) -> Void) {
        file.apply(undoManager, change)
    }

    private func mutateTree(_ change: (inout Tree) -> Void) {
        let treeID = currentTreeID
        mutate { $0.updateTree(treeID, change) }
    }

    // MARK: - 選択・編集

    func select(_ id: UUID) {
        if editingID != nil, editingID != id { commitEdit() }
        selectedID = id
        focusToken += 1
    }

    func beginEdit(_ id: UUID? = nil, replacingWith event: NSEvent? = nil) {
        guard let id = id ?? selectedID, let node = currentTree.root.find(id) else { return }
        selectedID = id
        draft = event == nil ? node.text : ""
        pendingKeyEvent = event
        editingID = id
    }

    func commitEdit() {
        guard let id = editingID else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let treeID = currentTreeID
        editingID = nil
        pendingKeyEvent = nil
        if currentTree.root.find(id)?.text != text {
            mutate { $0.setText(text, node: id, in: treeID) }
        }
        focusToken += 1
    }

    // MARK: - 構造の編集

    func addSibling() {
        commitEdit()
        guard let selected = selectedID else { return }
        var newID: UUID?
        mutateTree { newID = $0.addSibling(after: selected) }
        if let newID { beginEdit(newID) }
    }

    func addChild() {
        commitEdit()
        guard let selected = selectedID else { return }
        var newID: UUID?
        mutateTree { newID = $0.addChild(to: selected) }
        if let newID { beginEdit(newID) }
    }

    func indent() {
        commitEdit()
        guard let selected = selectedID else { return }
        mutateTree { $0.indent(selected) }
    }

    func outdent() {
        commitEdit()
        guard let selected = selectedID else { return }
        mutateTree { $0.outdent(selected) }
    }

    func move(by offset: Int) {
        commitEdit()
        guard let selected = selectedID else { return }
        mutateTree { $0.move(selected, by: offset) }
    }

    func deleteSelected() {
        commitEdit()
        guard let selected = selectedID, selected != currentTree.root.id else { return }
        let treeID = currentTreeID
        var next: UUID?
        mutate { next = $0.deleteNode(selected, in: treeID) }
        selectedID = next ?? currentTree.root.id
    }

    func toggleRed() {
        guard let selected = selectedID else { return }
        let treeID = currentTreeID
        mutate { $0.toggleRed(node: selected, in: treeID) }
    }

    func navigate(_ direction: Direction) {
        guard let selected = selectedID else {
            selectedID = currentTree.root.id
            return
        }
        if let next = layout(for: currentTree).neighbor(of: selected, direction) {
            selectedID = next
        }
    }

    // MARK: - ツリー間の移動

    func openTree(_ id: UUID, select nodeID: UUID? = nil) {
        commitEdit()
        guard let tree = file.doc.tree(id) else { return }
        currentTreeID = id
        selectedID = nodeID ?? tree.root.id
        focusToken += 1
    }

    /// 選択ノードを深掘り（なければ新しいツリーを作る）
    func drillDown() {
        commitEdit()
        guard let selected = selectedID else { return }
        let treeID = currentTreeID
        let isNew = currentTree.root.find(selected)?.drillTreeID.flatMap { file.doc.tree($0) } == nil
        var drillID: UUID?
        mutate { drillID = $0.drillDown(node: selected, in: treeID) }
        guard let drillID else { return }
        openTree(drillID)
        if isNew, let root = file.doc.tree(drillID)?.root, root.children.isEmpty {
            addChild()
        }
    }

    var canGoToParent: Bool { currentTree.parentLink != nil }

    func goToParentTree() {
        guard let link = currentTree.parentLink else { return }
        openTree(link.treeID, select: link.nodeID)
    }

    func newTree() {
        commitEdit()
        var id: UUID?
        mutate { id = $0.addTree() }
        if let id {
            openTree(id)
            beginEdit()
        }
    }

    func deleteTree(_ id: UUID) {
        commitEdit()
        mutate { $0.deleteTree(id) }
        validate()
    }

    func importTrees(_ trees: [Tree]) {
        guard !trees.isEmpty else { return }
        commitEdit()
        mutate { $0.trees.append(contentsOf: trees) }
        openTree(trees[0].id)
    }

    // MARK: - キー入力（非編集時）

    func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if flags.contains(.command) || flags.contains(.control) { return false }
        let option = flags.contains(.option)
        let shift = flags.contains(.shift)

        switch event.keyCode {
        case 36, 76: // Return / Enter
            addSibling()
        case 48: // Tab
            shift ? outdent() : addChild()
        case 51, 117: // Delete
            deleteSelected()
        case 49, 120: // Space / F2
            beginEdit()
        case 126: option ? move(by: -1) : navigate(.up)
        case 125: option ? move(by: 1) : navigate(.down)
        case 123: option ? outdent() : navigate(.left)
        case 124: option ? indent() : navigate(.right)
        case 53: // Esc
            break
        default:
            guard let chars = event.characters, let scalar = chars.unicodeScalars.first,
                  !CharacterSet.controlCharacters.contains(scalar),
                  scalar.value < 0xF700 || scalar.value > 0xF8FF // 矢印・ファンクションキー
            else { return false }
            beginEdit(replacingWith: event)
        }
        return true
    }
}
