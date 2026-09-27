import AppKit
import SwiftUI

/// 非編集時のキー入力を受け取る透明なビュー
struct KeyCatcher: NSViewRepresentable {
    var isEditing: Bool
    var focusToken: Int
    var onKey: (NSEvent) -> Bool

    final class CatcherView: NSView {
        var onKey: ((NSEvent) -> Bool)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if onKey?(event) != true { super.keyDown(with: event) }
        }
    }

    func makeNSView(context: Context) -> CatcherView {
        CatcherView()
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onKey = onKey
        guard !isEditing else { return }
        DispatchQueue.main.async {
            guard let window = view.window, window.firstResponder !== view,
                  !(window.firstResponder is NSTextView) else { return }
            window.makeFirstResponder(view)
        }
    }
}

/// ノード内のテキスト編集（日本語 IME の変換中 Enter は確定として扱われる）
struct NodeTextEditor: NSViewRepresentable {
    @ObservedObject var editor: EditorState
    let nodeID: UUID
    var isRed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(editor: editor, nodeID: nodeID) }

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = NodeMetrics.font
        textView.textColor = isRed ? .systemRed : .labelColor
        textView.textContainerInset = NSSize(width: NodeMetrics.horizontalPadding - 5, height: NodeMetrics.verticalPadding)
        textView.textContainer?.lineFragmentPadding = 5
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.string = editor.draft

        DispatchQueue.main.async { [editor] in
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            if let event = editor.pendingKeyEvent {
                editor.pendingKeyEvent = nil
                textView.keyDown(with: event)
            }
        }
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        textView.textColor = isRed ? .systemRed : .labelColor
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let editor: EditorState
        let nodeID: UUID

        init(editor: EditorState, nodeID: UUID) {
            self.editor = editor
            self.nodeID = nodeID
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            MainActor.assumeIsolated { editor.draft = textView.string }
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            MainActor.assumeIsolated {
                switch selector {
                case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.cancelOperation(_:)):
                    editor.commitEdit()
                case #selector(NSResponder.insertTab(_:)):
                    editor.addChild()
                case #selector(NSResponder.insertBacktab(_:)):
                    editor.commitEdit()
                    editor.outdent()
                default:
                    return false // ⌥Enter などは改行として通常処理
                }
                return true
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            MainActor.assumeIsolated {
                if editor.editingID == nodeID { editor.commitEdit() }
            }
        }
    }
}
