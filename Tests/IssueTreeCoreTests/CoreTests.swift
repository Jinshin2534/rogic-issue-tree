import XCTest
@testable import IssueTreeCore

final class TreeTests: XCTestCase {
    func testAddSiblingAndChild() {
        var tree = Tree(root: Node(text: "top"))
        let a = tree.addSibling(after: tree.root.id, text: "a")!   // トップでは子になる
        let b = tree.addSibling(after: a, text: "b")!
        let a1 = tree.addChild(to: a, text: "a1")!
        XCTAssertEqual(tree.root.children.map(\.text), ["a", "b"])
        XCTAssertEqual(tree.root.find(a)?.children.map(\.id), [a1])
        XCTAssertEqual(tree.parentID(of: b), tree.root.id)
    }

    func testIndentOutdentMove() {
        var tree = Tree(root: Node(text: "top"))
        let a = tree.addChild(to: tree.root.id, text: "a")!
        let b = tree.addChild(to: tree.root.id, text: "b")!
        XCTAssertFalse(tree.indent(a))
        XCTAssertTrue(tree.indent(b))
        XCTAssertEqual(tree.parentID(of: b), a)
        XCTAssertTrue(tree.outdent(b))
        XCTAssertEqual(tree.root.children.map(\.text), ["a", "b"])
        XCTAssertFalse(tree.outdent(b))
        XCTAssertTrue(tree.move(b, by: -1))
        XCTAssertEqual(tree.root.children.map(\.text), ["b", "a"])
        XCTAssertFalse(tree.move(b, by: -1))
    }

    func testRemoveSelectsNeighbor() {
        var tree = Tree(root: Node(text: "top"))
        let a = tree.addChild(to: tree.root.id)!
        let b = tree.addChild(to: tree.root.id)!
        XCTAssertNil(tree.remove(tree.root.id))
        XCTAssertEqual(tree.remove(b)?.next, a)
        XCTAssertEqual(tree.remove(a)?.next, tree.root.id)
    }
}

final class DocumentTests: XCTestCase {
    func testDrillDownCreatesLinkedTreeAndReusesIt() {
        var doc = IssueDocument()
        let mainID = doc.trees[0].id
        var nodeID: UUID!
        doc.updateTree(mainID) { nodeID = $0.addChild(to: $0.root.id, text: "深掘り対象") }

        let drillID = doc.drillDown(node: nodeID, in: mainID)!
        XCTAssertEqual(doc.trees.count, 2)
        XCTAssertEqual(doc.tree(drillID)?.root.text, "深掘り対象")
        XCTAssertEqual(doc.tree(drillID)?.parentLink, NodeRef(treeID: mainID, nodeID: nodeID))
        XCTAssertEqual(doc.tree(mainID)?.root.find(nodeID)?.drillTreeID, drillID)
        XCTAssertEqual(doc.drillDown(node: nodeID, in: mainID), drillID)
        XCTAssertEqual(doc.trees.count, 2)
        XCTAssertEqual(doc.outline().map(\.depth), [0, 1])
    }

    func testTextSyncsBothWays() {
        var doc = IssueDocument()
        let mainID = doc.trees[0].id
        var nodeID: UUID!
        doc.updateTree(mainID) { nodeID = $0.addChild(to: $0.root.id, text: "x") }
        let drillID = doc.drillDown(node: nodeID, in: mainID)!

        doc.setText("元で変更", node: nodeID, in: mainID)
        XCTAssertEqual(doc.tree(drillID)?.root.text, "元で変更")
        doc.setText("先で変更", node: doc.tree(drillID)!.root.id, in: drillID)
        XCTAssertEqual(doc.tree(mainID)?.root.find(nodeID)?.text, "先で変更")
    }

    func testDeletingClearsLinks() {
        var doc = IssueDocument()
        let mainID = doc.trees[0].id
        var nodeID: UUID!
        doc.updateTree(mainID) { nodeID = $0.addChild(to: $0.root.id, text: "x") }
        let drillID = doc.drillDown(node: nodeID, in: mainID)!

        var copy = doc
        XCTAssertTrue(copy.deleteTree(drillID))
        XCTAssertNil(copy.tree(mainID)?.root.find(nodeID)?.drillTreeID)
        XCTAssertFalse(copy.deleteTree(mainID))

        doc.deleteNode(nodeID, in: mainID)
        XCTAssertNil(doc.tree(drillID)?.parentLink)
    }

    func testDrillDownKeepsOrOverridesKind() {
        var doc = IssueDocument(trees: [Tree(root: Node(text: "問題"), kind: .why)])
        let mainID = doc.trees[0].id
        var a: UUID!, b: UUID!
        doc.updateTree(mainID) {
            a = $0.addChild(to: $0.root.id, text: "原因A")
            b = $0.addChild(to: $0.root.id, text: "原因B")
        }
        let sameKind = doc.drillDown(node: a, in: mainID)!
        let howKind = doc.drillDown(node: b, in: mainID, kind: .how)!
        let whatTree = doc.addTree(kind: .what)
        XCTAssertEqual(doc.tree(sameKind)?.kind, .why)
        XCTAssertEqual(doc.tree(howKind)?.kind, .how)
        XCTAssertEqual(doc.tree(whatTree)?.kind, .what)
    }

    func testDecodesFilesWithoutKind() throws {
        let json = #"{"trees":[{"id":"8D0E5A3C-1F2B-4C3D-9E8F-0A1B2C3D4E5F","root":{"id":"1D0E5A3C-1F2B-4C3D-9E8F-0A1B2C3D4E5F","text":"x","isRed":false,"children":[]}}]}"#
        let doc = try JSONDecoder().decode(IssueDocument.self, from: Data(json.utf8))
        XCTAssertEqual(doc.trees[0].kind, .issue)
    }

    func testCodableRoundTrip() throws {
        var doc = IssueDocument(trees: [Tree(kind: .how)])
        doc.updateTree(doc.trees[0].id) { $0.addChild(to: $0.root.id, text: "a") }
        let data = try JSONEncoder().encode(doc)
        XCTAssertEqual(try JSONDecoder().decode(IssueDocument.self, from: data), doc)
    }
}

final class MarkdownTests: XCTestCase {
    func testExport() {
        let tree = Tree(root: Node(text: "top", children: [
            Node(text: "a", children: [Node(text: "a1", isRed: true)]),
            Node(text: "b"),
        ]))
        XCTAssertEqual(MarkdownCodec.export(tree), "# top\n\n- a\n  - **a1**\n- b")
    }

    func testRoundTrip() {
        let tree = Tree(root: Node(text: "top", children: [
            Node(text: "a", children: [Node(text: "a1", isRed: true), Node(text: "a2")]),
            Node(text: "b"),
        ]))
        let parsed = MarkdownCodec.parse(MarkdownCodec.export(tree))
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(MarkdownCodec.export(parsed[0]), MarkdownCodec.export(tree))
    }

    func testParsePlainIndentedText() {
        let trees = MarkdownCodec.parse("課題\n\t原因1\n\t\t深い原因\n\t原因2")
        XCTAssertEqual(trees.count, 1)
        XCTAssertEqual(trees[0].root.text, "課題")
        XCTAssertEqual(trees[0].root.children.map(\.text), ["原因1", "原因2"])
        XCTAssertEqual(trees[0].root.children[0].children.map(\.text), ["深い原因"])
    }

    func testParseMultipleHeadingsAndMultipleTopItems() {
        XCTAssertEqual(MarkdownCodec.parse("# A\n- a\n# B\n- b").map(\.root.text), ["A", "B"])
        let t = MarkdownCodec.parse("- x\n- y")[0]
        XCTAssertEqual(t.root.text, "")
        XCTAssertEqual(t.root.children.map(\.text), ["x", "y"])
    }
}

final class LayoutTests: XCTestCase {
    func testParentCenteredOnChildrenAndColumns() {
        let root = Node(text: "top", children: [Node(text: "a"), Node(text: "b"), Node(text: "c")])
        let layout = TreeLayout.compute(root: root) { _ in 40 }
        let r = layout.frames[root.id]!
        let a = layout.frames[root.children[0].id]!
        let c = layout.frames[root.children[2].id]!
        XCTAssertEqual(r.midY, (a.midY + c.midY) / 2, accuracy: 0.01)
        XCTAssertEqual(a.minX, layout.config.columnX(1))
        XCTAssertEqual(layout.columnCount, 2)
        XCTAssertEqual(a.minY, layout.config.contentTop)
    }

    func testTallParentDoesNotOverlap() {
        let root = Node(text: "top", children: [
            Node(text: "tall", children: [Node(text: "x")]),
            Node(text: "b"),
        ])
        let layout = TreeLayout.compute(root: root) { $0.text == "tall" ? 200 : 40 }
        let tall = layout.frames[root.children[0].id]!
        let b = layout.frames[root.children[1].id]!
        XCTAssertGreaterThanOrEqual(tall.minY, layout.config.contentTop)
        XCTAssertGreaterThan(b.minY, tall.maxY)
    }

    func testNeighbor() {
        let root = Node(text: "top", children: [Node(text: "a"), Node(text: "b")])
        let layout = TreeLayout.compute(root: root) { _ in 40 }
        let a = root.children[0].id, b = root.children[1].id
        XCTAssertEqual(layout.neighbor(of: a, .down), b)
        XCTAssertEqual(layout.neighbor(of: b, .up), a)
        XCTAssertEqual(layout.neighbor(of: a, .left), root.id)
        XCTAssertNotNil(layout.neighbor(of: root.id, .right))
        XCTAssertNil(layout.neighbor(of: a, .up))
    }
}
