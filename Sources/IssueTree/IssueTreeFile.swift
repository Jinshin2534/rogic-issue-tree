import IssueTreeCore
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let issueTree = UTType(exportedAs: "com.nokokoro.issuetree", conformingTo: .json)
}

/// .issuetree ファイル（中身は IssueDocument の JSON）
final class IssueTreeFile: ReferenceFileDocument {
    typealias Snapshot = IssueDocument

    static var readableContentTypes: [UTType] { [.issueTree] }

    @Published var doc: IssueDocument

    init() {
        doc = IssueDocument()
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        doc = try JSONDecoder().decode(IssueDocument.self, from: data)
    }

    func snapshot(contentType: UTType) throws -> IssueDocument { doc }

    func fileWrapper(snapshot: IssueDocument, configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(snapshot))
    }

    /// 変更を1つの取り消し単位として適用
    func apply(_ undoManager: UndoManager?, _ change: (inout IssueDocument) -> Void) {
        let old = doc
        var new = doc
        change(&new)
        guard new != old else { return }
        doc = new
        undoManager?.registerUndo(withTarget: self) { $0.restore(old, undoManager) }
    }

    private func restore(_ value: IssueDocument, _ undoManager: UndoManager?) {
        let current = doc
        doc = value
        undoManager?.registerUndo(withTarget: self) { $0.restore(current, undoManager) }
    }
}
