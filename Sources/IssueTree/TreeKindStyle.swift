import IssueTreeCore
import SwiftUI

/// ツリーの種類ごとの見出し・入力例・問いかけ
extension TreeKind {
    var title: String {
        switch self {
        case .issue: "イシューツリー"
        case .why: "Whyツリー（原因）"
        case .how: "Howツリー（打ち手）"
        case .what: "Whatツリー（要素）"
        }
    }

    var symbol: String {
        switch self {
        case .issue: "list.bullet.indent"
        case .why: "questionmark.circle"
        case .how: "wrench.and.screwdriver"
        case .what: "square.split.2x2"
        }
    }

    /// 右へ分けるときの問いかけ
    var prompt: String {
        switch self {
        case .issue: "トップの問いを、答えを出せる大きさの問いに分ける"
        case .why: "右へ「なぜ？」と問い、原因を分ける。左へ「だから？」で筋を確かめる"
        case .how: "右へ「どうやって？」と問い、明日から動ける行動まで具体化する"
        case .what: "右へ「何でできている？」と問い、全体を要素に分ける"
        }
    }

    var guidePageID: String {
        switch self {
        case .issue: "basics"
        case .why: "why"
        case .how: "how"
        case .what: "what"
        }
    }

    func header(depth: Int) -> String {
        let circled = Array("①②③④⑤⑥⑦⑧⑨⑩")
        let number = (1...circled.count).contains(depth) ? String(circled[depth - 1]) : "\(depth)"
        switch self {
        case .issue: return depth == 0 ? "トップイシュー" : "\(depth)層目"
        case .why: return depth == 0 ? "問題" : "なぜ\(number)"
        case .how: return depth == 0 ? "目的" : "手段\(number)"
        case .what: return depth == 0 ? "全体" : "要素\(number)"
        }
    }

    func placeholder(depth: Int) -> String {
        switch self {
        case .issue: depth == 0 ? "答えを出したい問い" : "より小さな問い"
        case .why: depth == 0 ? "起きている問題" : "〜だから"
        case .how: depth == 0 ? "達成したい目的" : "〜する"
        case .what: depth == 0 ? "分解したい全体" : "〜の内訳"
        }
    }
}

/// キャンバス上部：種類の切り替えと問いかけ
struct KindBar: View {
    @ObservedObject var editor: EditorState
    let kind: TreeKind

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("ツリーの種類", selection: Binding(get: { kind }, set: { editor.setKind($0) })) {
                    ForEach(TreeKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(kind.title, systemImage: kind.symbol)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("このツリーの種類を切り替える")
            Text(kind.prompt)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("作り方を見る") { editor.openGuide(kind.guidePageID) }
                .buttonStyle(.link)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }
}

/// 種類を選んで新しいツリーを作るメニューの中身
struct NewTreeMenuItems: View {
    let editor: EditorState

    var body: some View {
        ForEach(TreeKind.allCases, id: \.self) { kind in
            Button { editor.newTree(kind: kind) } label: {
                Label(kind.title, systemImage: kind.symbol)
            }
        }
    }
}
