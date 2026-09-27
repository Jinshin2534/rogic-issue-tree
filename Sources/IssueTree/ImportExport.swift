import AppKit
import IssueTreeCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum ImportExport {
    private static let markdownType = UTType(filenameExtension: "md") ?? .plainText

    static func copyMarkdown(_ editor: EditorState) {
        editor.commitEdit()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(MarkdownCodec.export(editor.file.doc), forType: .string)
    }

    static func exportMarkdown(_ editor: EditorState) {
        editor.commitEdit()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [markdownType]
        panel.nameFieldStringValue = fileName(editor.currentTree) + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write { try MarkdownCodec.export(editor.file.doc).write(to: url, atomically: true, encoding: .utf8) }
    }

    static func exportPNG(_ editor: EditorState) {
        editor.commitEdit()
        let tree = editor.currentTree
        let renderer = ImageRenderer(content: StaticTreeView(tree: tree, layout: editor.layout(for: tree)))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = fileName(tree) + ".png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write { try png.write(to: url) }
    }

    static func importFromClipboard(_ editor: EditorState) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        editor.importTrees(MarkdownCodec.parse(text))
    }

    static func importMarkdownFile(_ editor: EditorState) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [markdownType, .plainText]
        guard panel.runModal() == .OK, let url = panel.url,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        editor.importTrees(MarkdownCodec.parse(text))
    }

    private static func fileName(_ tree: Tree) -> String {
        let title = tree.root.text.components(separatedBy: CharacterSet(charactersIn: "/:\n")).joined(separator: " ")
        return title.isEmpty ? "イシューツリー" : String(title.prefix(40))
    }

    private static func write(_ body: () throws -> Void) {
        do { try body() } catch { NSAlert(error: error).runModal() }
    }
}

struct ExportMenuItems: View {
    let editor: EditorState

    var body: some View {
        Button("クリップボードから読み込む") { ImportExport.importFromClipboard(editor) }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        Button("Markdown / テキストを読み込む…") { ImportExport.importMarkdownFile(editor) }
        Divider()
        Button("Markdownをコピー") { ImportExport.copyMarkdown(editor) }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        Button("Markdownで書き出す…") { ImportExport.exportMarkdown(editor) }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        Button("PNGで書き出す…") { ImportExport.exportPNG(editor) }
            .keyboardShortcut("e", modifiers: [.command, .option])
    }
}
