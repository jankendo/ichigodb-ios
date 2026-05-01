import SwiftUI

struct PedigreeView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @ObservedObject var viewModel: PedigreeGraphViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                controls
                    .padding(.horizontal)
                    .padding(.top, 12)

                GeometryReader { proxy in
                    let graph = viewModel.graph(varieties: library.varieties, links: library.parentLinks, canvasSize: proxy.size)
                    ZStack {
                        AppTheme.surface
                        edgeCanvas(nodes: graph.nodes, edges: graph.edges)
                        ForEach(graph.nodes) { node in
                            nodeButton(node)
                        }
                        if graph.nodes.isEmpty {
                            emptyState
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
                }
                .padding(.horizontal)

                selectedPanel
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .navigationTitle("交配図")
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("起点品種", selection: $viewModel.rootID) {
                Text("全体").tag("")
                ForEach(library.varieties) { variety in
                    Text(variety.name).tag(variety.id)
                }
            }
            .pickerStyle(.menu)

            Picker("表示方向", selection: $viewModel.direction) {
                ForEach(PedigreeDirection.allCases) { direction in
                    Text(direction.label).tag(direction)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Stepper("深さ \(viewModel.maxDepth)", value: $viewModel.maxDepth, in: 1...5)
                Stepper("最大 \(viewModel.maxNodes)", value: $viewModel.maxNodes, in: 30...120, step: 10)
            }
            .font(.subheadline)
        }
    }

    private func edgeCanvas(nodes: [PedigreeNode], edges: [PedigreeEdge]) -> some View {
        let points = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.point) })
        return Canvas { context, _ in
            var path = Path()
            for edge in edges {
                guard let start = points[edge.parentID], let end = points[edge.childID] else { continue }
                path.move(to: start)
                let midY = (start.y + end.y) / 2
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: start.x, y: midY),
                    control2: CGPoint(x: end.x, y: midY)
                )
            }
            context.stroke(path, with: .color(AppTheme.muted.opacity(0.55)), lineWidth: 1.4)
        }
    }

    private func nodeButton(_ node: PedigreeNode) -> some View {
        Button {
            viewModel.selectedNodeID = node.id
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(node.layer == 0 ? AppTheme.leaf : AppTheme.strawberry)
                    .frame(width: 18, height: 18)
                Text(node.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 96)
            }
            .padding(8)
            .background(.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(viewModel.selectedNodeID == node.id ? AppTheme.strawberry : AppTheme.line, lineWidth: viewModel.selectedNodeID == node.id ? 2 : 1))
        }
        .buttonStyle(.plain)
        .position(node.point)
    }

    private var selectedPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let id = viewModel.selectedNodeID {
                Text(library.varietyName(id))
                    .font(.headline)
                HStack {
                    CapsuleBadge(text: "評価 \(library.reviewCount(for: id))件", tint: AppTheme.leaf)
                    CapsuleBadge(text: "ノード選択中", tint: AppTheme.strawberry)
                    Spacer()
                }
            } else {
                Text("ノードをタップすると品種情報を確認できます。")
                    .foregroundStyle(AppTheme.muted)
            }
            ErrorBanner(message: viewModel.errorMessage)
        }
        .cardSurface()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.muted)
            Text("交配リンクがありません")
                .font(.headline)
            Text("品種登録タブで親品種を設定すると表示されます。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
    }
}
