import XCTest
@testable import IchigoDB

final class PedigreeLayoutTests: XCTestCase {
    func testBuildsLayeredNodesForDAG() throws {
        let parent = Variety(id: "p", name: "親")
        let child = Variety(id: "c", name: "子")
        let link = VarietyParentLink(id: "l", childVarietyID: "c", parentVarietyID: "p")
        let edges = PedigreeLayout.buildEdges(varieties: [parent, child], links: [link])
        let nodes = try PedigreeLayout.makeNodes(varieties: [parent, child], edges: edges, size: CGSize(width: 600, height: 400))

        XCTAssertEqual(edges.count, 1)
        XCTAssertEqual(nodes.first(where: { $0.id == "p" })?.layer, 0)
        XCTAssertEqual(nodes.first(where: { $0.id == "c" })?.layer, 1)
    }

    func testCycleDetectionThrows() {
        let a = Variety(id: "a", name: "A")
        let b = Variety(id: "b", name: "B")
        let edges = [
            PedigreeEdge(parentID: "a", childID: "b"),
            PedigreeEdge(parentID: "b", childID: "a")
        ]
        XCTAssertThrowsError(try PedigreeLayout.makeNodes(varieties: [a, b], edges: edges, size: CGSize(width: 500, height: 300)))
    }
}
