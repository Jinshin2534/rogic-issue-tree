import IssueTreeCore
import SwiftUI

/// 論理的思考のガイド（1ページ分）
struct GuideView: View {
    @ObservedObject var editor: EditorState
    let page: GuidePage

    var body: some View {
        ScrollView {
            GuidePageContent(page: page) { markdown in
                editor.importTrees(MarkdownCodec.parse(markdown))
            } openPage: { id in
                editor.openGuide(id)
            }
            .padding(32)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .id(page.id) // ページ切り替え時に先頭へ戻す
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct GuidePageContent: View {
    let page: GuidePage
    var useExample: ((String) -> Void)?
    var openPage: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(page.title, systemImage: page.symbol)
                .font(.system(size: 26, weight: .bold))
            Text(page.lead)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(page.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
            pager.padding(.top, 12)
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: GuideBlock) -> some View {
        switch block {
        case let .heading(text):
            Text(text).font(.system(size: 18, weight: .semibold)).padding(.top, 8)
        case let .paragraph(text):
            bodyText(text)
        case let .bullets(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        bodyText(item)
                    }
                }
            }
        case let .terms(pairs):
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
                ForEach(pairs, id: \.0) { term, detail in
                    GridRow {
                        Text(term).font(.system(size: 14, weight: .semibold))
                            .frame(width: 190, alignment: .leading)
                        bodyText(detail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        case let .tip(text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                bodyText(text)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        case let .checklist(items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "checkmark.square").foregroundStyle(Color.accentColor)
                        bodyText(item)
                    }
                }
            }
        case let .example(title, markdown):
            ExampleTree(title: title, markdown: markdown, use: useExample)
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var pager: some View {
        let pages = Guide.pages
        let index = pages.firstIndex { $0.id == page.id } ?? 0
        HStack {
            if index > 0 {
                Button { openPage?(pages[index - 1].id) } label: {
                    Label(pages[index - 1].title, systemImage: "chevron.left")
                }
            }
            Spacer()
            if index < pages.count - 1 {
                Button { openPage?(pages[index + 1].id) } label: {
                    HStack(spacing: 4) {
                        Text(pages[index + 1].title)
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .controlSize(.large)
    }
}

private struct ExampleTree: View {
    let title: String
    let markdown: String
    let use: ((String) -> Void)?

    var body: some View {
        let tree = MarkdownCodec.parse(markdown).first ?? Tree()
        var config = LayoutConfig()
        config.nodeWidth = 190
        config.columnGap = 32
        config.padding = 16
        let layout = TreeLayout.compute(root: tree.root, config: config) {
            NodeMetrics.height(for: $0.text, width: config.nodeWidth)
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer()
                if let use {
                    Button("この例からツリーを作る") { use(markdown) }
                }
            }
            StaticTreeView(tree: tree, layout: layout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.3)))
        }
        .padding(.top, 4)
    }
}

@MainActor
enum GuideSnapshot {
    static func write(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for page in Guide.pages {
            let view = GuidePageContent(page: page, useExample: { _ in }, openPage: { _ in })
                .padding(32)
                .frame(width: 820, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.white)
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            guard let tiff = renderer.nsImage?.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: directory.appendingPathComponent("\(page.id).png"))
        }
    }
}
