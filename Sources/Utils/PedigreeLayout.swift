import Foundation
import CoreGraphics

enum PedigreeLayoutError: LocalizedError, Equatable {
    case cycleDetected

    var errorDescription: String? {
        switch self {
        case .cycleDetected:
            return "交配図に循環が検出されました。親子リンクを確認してください。"
        }
    }
}

enum PedigreeLayout {
    static func buildEdges(varieties: [Variety], links: [VarietyParentLink]) -> [PedigreeEdge] {
        let ids = Set(varieties.map(\.id))
        return links.compactMap { link in
            guard ids.contains(link.parentVarietyID), ids.contains(link.childVarietyID) else { return nil }
            return PedigreeEdge(parentID: link.parentVarietyID, childID: link.childVarietyID)
        }
    }

    static func subgraph(
        rootID: String?,
        direction: PedigreeDirection,
        maxDepth: Int,
        varieties: [Variety],
        edges: [PedigreeEdge]
    ) -> ([Variety], [PedigreeEdge]) {
        guard let rootID, !rootID.isEmpty else { return (varieties, edges) }
        let byParent = Dictionary(grouping: edges, by: \.parentID)
        let byChild = Dictionary(grouping: edges, by: \.childID)
        var visited: Set<String> = [rootID]
        var queue: [(String, Int)] = [(rootID, 0)]
        while !queue.isEmpty {
            let (node, depth) = queue.removeFirst()
            guard depth < maxDepth else { continue }
            var next = [String]()
            if direction == .descendants || direction == .both {
                next += byParent[node, default: []].map(\.childID)
            }
            if direction == .ancestors || direction == .both {
                next += byChild[node, default: []].map(\.parentID)
            }
            for candidate in next where !visited.contains(candidate) {
                visited.insert(candidate)
                queue.append((candidate, depth + 1))
            }
        }
        let filteredVarieties = varieties.filter { visited.contains($0.id) }
        let filteredEdges = edges.filter { visited.contains($0.parentID) && visited.contains($0.childID) }
        return (filteredVarieties, filteredEdges)
    }

    static func makeNodes(varieties: [Variety], edges: [PedigreeEdge], size: CGSize) throws -> [PedigreeNode] {
        let ids = varieties.map(\.id)
        let incoming = Dictionary(grouping: edges, by: \.childID)
        let outgoing = Dictionary(grouping: edges, by: \.parentID)
        var indegree = Dictionary(uniqueKeysWithValues: ids.map { ($0, incoming[$0, default: []].count) })
        var queue = ids.filter { indegree[$0, default: 0] == 0 }.sorted()
        var order = [String]()
        while !queue.isEmpty {
            let node = queue.removeFirst()
            order.append(node)
            for edge in outgoing[node, default: []] {
                indegree[edge.childID, default: 0] -= 1
                if indegree[edge.childID] == 0 {
                    queue.append(edge.childID)
                    queue.sort()
                }
            }
        }
        guard order.count == ids.count else { throw PedigreeLayoutError.cycleDetected }

        var depth = [String: Int]()
        for node in order {
            let parents = incoming[node, default: []].map(\.parentID)
            depth[node] = (parents.compactMap { depth[$0] }.max() ?? -1) + 1
        }
        let byDepth = Dictionary(grouping: ids) { depth[$0, default: 0] }
        let maxLayer = max(byDepth.keys.max() ?? 0, 1)
        let usableWidth = max(size.width - 48, 320)
        let usableHeight = max(size.height - 64, 420)
        let varietyByID = Dictionary(uniqueKeysWithValues: varieties.map { ($0.id, $0) })

        return byDepth.keys.sorted().flatMap { layer -> [PedigreeNode] in
            let layerIDs = (byDepth[layer] ?? []).sorted { (varietyByID[$0]?.name ?? $0) < (varietyByID[$1]?.name ?? $1) }
            return layerIDs.enumerated().map { index, id in
                let xStep = usableWidth / CGFloat(max(layerIDs.count, 1) + 1)
                let yStep = usableHeight / CGFloat(maxLayer + 1)
                return PedigreeNode(
                    id: id,
                    name: varietyByID[id]?.name ?? id,
                    point: CGPoint(x: 24 + xStep * CGFloat(index + 1), y: 32 + yStep * CGFloat(layer + 1)),
                    layer: layer
                )
            }
        }
    }
}
