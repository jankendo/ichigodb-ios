import Foundation
import CoreGraphics

@MainActor
final class PedigreeGraphViewModel: ObservableObject {
    @Published var rootID = ""
    @Published var direction: PedigreeDirection = .both
    @Published var maxDepth = 3
    @Published var maxNodes = 80
    @Published var selectedNodeID: String?
    @Published var rootSearchText = ""
    @Published var zoomScale: CGFloat = 1
    @Published var panOffset: CGSize = .zero
    @Published var errorMessage: String?

    func resetViewport() {
        zoomScale = 1
        panOffset = .zero
    }

    func commitPan(_ translation: CGSize) {
        panOffset = CGSize(
            width: panOffset.width + translation.width,
            height: panOffset.height + translation.height
        )
    }

    func commitZoom(_ scale: CGFloat) {
        zoomScale = min(2.8, max(0.55, zoomScale * scale))
    }

    func graph(
        varieties: [Variety],
        links: [VarietyParentLink],
        canvasSize: CGSize
    ) -> (nodes: [PedigreeNode], edges: [PedigreeEdge]) {
        let active = varieties.filter { $0.deletedAt == nil }
        let allEdges = PedigreeLayout.buildEdges(varieties: active, links: links)
        let selectedRoot = rootID.isEmpty ? nil : rootID
        var (subVarieties, subEdges) = PedigreeLayout.subgraph(
            rootID: selectedRoot,
            direction: direction,
            maxDepth: maxDepth,
            varieties: active,
            edges: allEdges
        )
        if subVarieties.count > maxNodes {
            let rootFirst = selectedRoot.map { [$0] } ?? []
            let ordered = rootFirst + subVarieties.map(\.id).filter { $0 != selectedRoot }
            let allowed = Set(ordered.prefix(maxNodes))
            subVarieties = subVarieties.filter { allowed.contains($0.id) }
            subEdges = subEdges.filter { allowed.contains($0.parentID) && allowed.contains($0.childID) }
        }
        do {
            return (try PedigreeLayout.makeNodes(varieties: subVarieties, edges: subEdges, size: canvasSize), subEdges)
        } catch {
            return ([], [])
        }
    }
}
