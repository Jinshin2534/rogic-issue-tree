import Foundation

public struct Node: Codable, Identifiable, Equatable {
    public var id: UUID
    public var text: String
    public var isRed: Bool
    public var children: [Node]
    /// 深掘りで作成したツリーのID
    public var drillTreeID: UUID?

    public init(id: UUID = UUID(), text: String = "", isRed: Bool = false, children: [Node] = [], drillTreeID: UUID? = nil) {
        self.id = id
        self.text = text
        self.isRed = isRed
        self.children = children
        self.drillTreeID = drillTreeID
    }

    public func path(to target: UUID) -> [Int]? {
        if id == target { return [] }
        for (i, child) in children.enumerated() {
            if let p = child.path(to: target) { return [i] + p }
        }
        return nil
    }

    public subscript(path: [Int]) -> Node {
        get { path.isEmpty ? self : children[path[0]][Array(path.dropFirst())] }
        set {
            if path.isEmpty { self = newValue } else { children[path[0]][Array(path.dropFirst())] = newValue }
        }
    }

    public func find(_ target: UUID) -> Node? {
        path(to: target).map { self[$0] }
    }

    /// 前順（自分→子）の全ノード
    public var allNodes: [Node] {
        [self] + children.flatMap(\.allNodes)
    }
}

public struct NodeRef: Codable, Equatable, Hashable {
    public var treeID: UUID
    public var nodeID: UUID

    public init(treeID: UUID, nodeID: UUID) {
        self.treeID = treeID
        self.nodeID = nodeID
    }
}

/// ツリーの種類（分解のしかた）
public enum TreeKind: String, Codable, CaseIterable {
    /// 問いを小さな問いに分ける
    case issue
    /// 問題の原因を「なぜ？」で分ける
    case why
    /// 目的の手段を「どうやって？」で分ける
    case how
    /// 全体を要素に分ける
    case what
}

public struct Tree: Codable, Identifiable, Equatable {
    public var id: UUID
    public var root: Node
    /// 深掘り元（どのツリーのどのノードから作られたか）
    public var parentLink: NodeRef?
    public var kind: TreeKind

    public init(id: UUID = UUID(), root: Node = Node(), parentLink: NodeRef? = nil, kind: TreeKind = .issue) {
        self.id = id
        self.root = root
        self.parentLink = parentLink
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey { case id, root, parentLink, kind }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        root = try c.decode(Node.self, forKey: .root)
        parentLink = try c.decodeIfPresent(NodeRef.self, forKey: .parentLink)
        // 種類が追加される前のファイルはイシューツリーとして読む
        kind = try c.decodeIfPresent(TreeKind.self, forKey: .kind) ?? .issue
    }

    public func parentID(of target: UUID) -> UUID? {
        guard let p = root.path(to: target), !p.isEmpty else { return nil }
        return root[Array(p.dropLast())].id
    }

    @discardableResult
    public mutating func addChild(to parent: UUID, text: String = "") -> UUID? {
        guard let p = root.path(to: parent) else { return nil }
        let node = Node(text: text)
        root[p].children.append(node)
        return node.id
    }

    /// 直後に兄弟を追加。トップでは子を追加する。
    @discardableResult
    public mutating func addSibling(after target: UUID, text: String = "") -> UUID? {
        guard let p = root.path(to: target) else { return nil }
        guard let index = p.last else { return addChild(to: target, text: text) }
        let node = Node(text: text)
        root[Array(p.dropLast())].children.insert(node, at: index + 1)
        return node.id
    }

    /// 直前の兄弟の最後の子にする
    @discardableResult
    public mutating func indent(_ target: UUID) -> Bool {
        guard let p = root.path(to: target), let index = p.last, index > 0 else { return false }
        let parentPath = Array(p.dropLast())
        let node = root[parentPath].children.remove(at: index)
        root[parentPath + [index - 1]].children.append(node)
        return true
    }

    /// 親の直後の兄弟にする
    @discardableResult
    public mutating func outdent(_ target: UUID) -> Bool {
        guard let p = root.path(to: target), p.count >= 2 else { return false }
        let parentPath = Array(p.dropLast())
        let grandPath = Array(parentPath.dropLast())
        let node = root[parentPath].children.remove(at: p.last!)
        root[grandPath].children.insert(node, at: parentPath.last! + 1)
        return true
    }

    @discardableResult
    public mutating func move(_ target: UUID, by offset: Int) -> Bool {
        guard let p = root.path(to: target), let index = p.last else { return false }
        let parentPath = Array(p.dropLast())
        let newIndex = index + offset
        guard root[parentPath].children.indices.contains(newIndex) else { return false }
        root[parentPath].children.swapAt(index, newIndex)
        return true
    }

    /// 子ごと削除。トップは削除できない。次に選択すべきノードを返す。
    public mutating func remove(_ target: UUID) -> (removed: Node, next: UUID)? {
        guard let p = root.path(to: target), let index = p.last else { return nil }
        let parentPath = Array(p.dropLast())
        let removed = root[parentPath].children.remove(at: index)
        let siblings = root[parentPath].children
        let next: UUID
        if index > 0 {
            next = siblings[index - 1].id
        } else if !siblings.isEmpty {
            next = siblings[0].id
        } else {
            next = root[parentPath].id
        }
        return (removed, next)
    }
}

public struct IssueDocument: Codable, Equatable {
    public var trees: [Tree]

    public init(trees: [Tree] = [Tree()]) {
        self.trees = trees.isEmpty ? [Tree()] : trees
    }

    public func tree(_ id: UUID) -> Tree? {
        trees.first { $0.id == id }
    }

    private func index(of treeID: UUID) -> Int? {
        trees.firstIndex { $0.id == treeID }
    }

    public mutating func updateTree(_ treeID: UUID, _ change: (inout Tree) -> Void) {
        guard let i = index(of: treeID) else { return }
        change(&trees[i])
    }

    private mutating func updateNode(_ ref: NodeRef, _ change: (inout Node) -> Void) {
        guard let i = index(of: ref.treeID), let p = trees[i].root.path(to: ref.nodeID) else { return }
        change(&trees[i].root[p])
    }

    /// テキスト更新。深掘り元ノードと深掘りツリーのトップは同期する。
    public mutating func setText(_ text: String, node nodeID: UUID, in treeID: UUID) {
        guard let tree = tree(treeID), let node = tree.root.find(nodeID) else { return }
        updateNode(NodeRef(treeID: treeID, nodeID: nodeID)) { $0.text = text }
        if let drill = node.drillTreeID, let drillTree = self.tree(drill) {
            updateNode(NodeRef(treeID: drill, nodeID: drillTree.root.id)) { $0.text = text }
        }
        if tree.root.id == nodeID, let link = tree.parentLink {
            updateNode(link) { $0.text = text }
        }
    }

    public mutating func toggleRed(node nodeID: UUID, in treeID: UUID) {
        updateNode(NodeRef(treeID: treeID, nodeID: nodeID)) { $0.isRed.toggle() }
    }

    /// ノード削除。削除したノードから深掘りしたツリーは残し、リンクだけ外す。
    @discardableResult
    public mutating func deleteNode(_ nodeID: UUID, in treeID: UUID) -> UUID? {
        guard let i = index(of: treeID), let result = trees[i].remove(nodeID) else { return nil }
        let orphaned = Set(result.removed.allNodes.compactMap(\.drillTreeID))
        for j in trees.indices where orphaned.contains(trees[j].id) {
            trees[j].parentLink = nil
        }
        return result.next
    }

    /// 深掘り：既にあればそのツリー、無ければノードをトップにした新しいツリーを作成してIDを返す。
    /// 種類を指定しなければ元のツリーと同じ種類にする。
    public mutating func drillDown(node nodeID: UUID, in treeID: UUID, kind: TreeKind? = nil) -> UUID? {
        guard let source = tree(treeID), let node = source.root.find(nodeID) else { return nil }
        if let existing = node.drillTreeID, tree(existing) != nil { return existing }
        let ref = NodeRef(treeID: treeID, nodeID: nodeID)
        let newTree = Tree(root: Node(text: node.text, isRed: node.isRed), parentLink: ref, kind: kind ?? source.kind)
        trees.append(newTree)
        updateNode(ref) { $0.drillTreeID = newTree.id }
        return newTree.id
    }

    @discardableResult
    public mutating func addTree(text: String = "", kind: TreeKind = .issue) -> UUID {
        let tree = Tree(root: Node(text: text), kind: kind)
        trees.append(tree)
        return tree.id
    }

    /// ツリー削除（最後の1つは削除しない）。深掘り元ノードのリンクと、子ツリーの親リンクを外す。
    @discardableResult
    public mutating func deleteTree(_ treeID: UUID) -> Bool {
        guard trees.count > 1, let i = index(of: treeID) else { return false }
        let removed = trees.remove(at: i)
        if let link = removed.parentLink {
            updateNode(link) { $0.drillTreeID = nil }
        }
        for j in trees.indices where trees[j].parentLink?.treeID == treeID {
            trees[j].parentLink = nil
        }
        return true
    }

    /// サイドバー表示用：深掘り関係に沿った順序と深さ
    public func outline() -> [(tree: Tree, depth: Int)] {
        let ids = Set(trees.map(\.id))
        var result: [(Tree, Int)] = []
        var visited: Set<UUID> = []
        func visit(_ tree: Tree, _ depth: Int) {
            guard visited.insert(tree.id).inserted else { return }
            result.append((tree, depth))
            for child in trees where child.parentLink?.treeID == tree.id {
                visit(child, depth + 1)
            }
        }
        for tree in trees where tree.parentLink.map({ !ids.contains($0.treeID) }) ?? true {
            visit(tree, 0)
        }
        for tree in trees where !visited.contains(tree.id) {
            visit(tree, 0)
        }
        return result
    }
}
