import SwiftUI

@main
struct IssueTreeApp: App {
    init() {
        // 開発用：`IssueTree --snapshot-guide <dir>` でガイド各ページを PNG に書き出して終了
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot-guide"), i + 1 < args.count {
            GuideSnapshot.write(to: URL(fileURLWithPath: args[i + 1]))
            exit(0)
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: { IssueTreeFile() }) { configuration in
            ContentView(file: configuration.document)
        }
        .defaultSize(width: 1280, height: 800)
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
        CommandGroup(replacing: .help) {
            Button("考え方ガイド") { editor?.openGuide() }
                .keyboardShortcut("?", modifiers: .command)
        }
        CommandGroup(replacing: .importExport) {
            if let editor {
                ExportMenuItems(editor: editor)
            }
        }
    }
}
