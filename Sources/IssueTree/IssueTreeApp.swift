import SwiftUI

@main
struct IssueTreeApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { IssueTreeFile() }) { configuration in
            ContentView(file: configuration.document)
        }
        .commands { TreeCommands() }
    }
}

struct TreeCommands: Commands {
    @FocusedObject private var editor: EditorState?

    var body: some Commands {
        CommandMenu("ツリー") {
            Button("赤字の切り替え") { editor?.toggleRed() }
                .keyboardShortcut("r", modifiers: .command)
            Divider()
            Button("深掘り") { editor?.drillDown() }
                .keyboardShortcut(.downArrow, modifiers: .command)
            Button("元のツリーへ戻る") { editor?.goToParentTree() }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(editor?.canGoToParent != true)
            Divider()
            Button("新しいツリー") { editor?.newTree() }
                .keyboardShortcut("n", modifiers: [.command, .option])
        }
        CommandGroup(replacing: .importExport) {
            if let editor {
                ExportMenuItems(editor: editor)
            }
        }
    }
}
