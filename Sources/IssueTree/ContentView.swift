import IssueTreeCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var file: IssueTreeFile
    @StateObject private var editor: EditorState
    @Environment(\.undoManager) private var undoManager

    init(file: IssueTreeFile) {
        self.file = file
        _editor = StateObject(wrappedValue: EditorState(file: file))
    }

    var body: some View {
        NavigationSplitView {
            TreeSidebar(editor: editor, doc: file.doc)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                if let link = editor.currentTree.parentLink, let parent = file.doc.tree(link.treeID) {
                    ParentBanner(parentTitle: parent.root.text) { editor.goToParentTree() }
                    Divider()
                }
                TreeCanvasView(editor: editor, tree: editor.currentTree)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) { ShortcutHints() }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { editor.drillDown() } label: {
                    Label("深掘り", systemImage: "arrow.down.right.circle")
                }
                .help("選択中のイシューをトップにした新しいツリーを作る (⌘↓)")
                Menu {
                    ExportMenuItems(editor: editor)
                } label: {
                    Label("入出力", systemImage: "square.and.arrow.up")
                }
            }
        }
        .focusedSceneObject(editor)
        .onAppear {
            editor.undoManager = undoManager
            if file.doc.trees.count == 1, file.doc.trees[0].root.text.isEmpty, file.doc.trees[0].root.children.isEmpty {
                editor.beginEdit()
            }
        }
        .onChange(of: undoManager) { _, new in editor.undoManager = new }
        .onChange(of: file.doc) { _, _ in editor.validate() }
    }
}

private struct ParentBanner: View {
    let parentTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Label("元のツリー：\(parentTitle.isEmpty ? "無題" : parentTitle)", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.link)
            .help("深掘り元のツリーへ戻る (⌘↑)")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct ShortcutHints: View {
    private let hints = [("Enter", "追加"), ("Tab", "子"), ("⌥↑↓", "入替"), ("⌘R", "赤字"), ("⌘↓", "深掘り"), ("⌘↑", "戻る")]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(hints, id: \.0) { key, label in
                HStack(spacing: 3) {
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TreeSidebar: View {
    @ObservedObject var editor: EditorState
    let doc: IssueDocument

    var body: some View {
        let selection = Binding<UUID?>(
            get: { editor.currentTreeID },
            set: { if let id = $0, id != editor.currentTreeID { editor.openTree(id) } }
        )
        List(selection: selection) {
            Section("ツリー") {
                ForEach(doc.outline(), id: \.tree.id) { tree, depth in
                    Label {
                        Text(tree.root.text.isEmpty ? "無題" : tree.root.text).lineLimit(1)
                    } icon: {
                        Image(systemName: depth == 0 ? "list.bullet.indent" : "arrow.turn.down.right")
                    }
                    .padding(.leading, CGFloat(depth) * 12)
                    .tag(tree.id)
                    .contextMenu {
                        Button("削除", role: .destructive) { editor.deleteTree(tree.id) }
                            .disabled(doc.trees.count <= 1)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { editor.newTree() } label: {
                Label("新しいツリー", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
