import SwiftUI

struct PedigreeView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @ObservedObject var viewModel: PedigreeGraphViewModel
    @ObservedObject var reviewVM: ReviewEditorViewModel
    @Binding var selectedTab: AppTab
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                controls
                    .padding(.horizontal)
                    .padding(.top, 12)

                GeometryReader { proxy in
                    let graph = viewModel.graph(varieties: library.varieties, links: library.parentLinks, canvasSize: proxy.size)
                    let currentScale = viewModel.zoomScale * pinchScale
                    let currentOffset = CGSize(
                        width: viewModel.panOffset.width + dragOffset.width,
                        height: viewModel.panOffset.height + dragOffset.height
                    )
                    ZStack {
                        AppTheme.surface
                        ZStack {
                            edgeCanvas(nodes: graph.nodes, edges: graph.edges)
                            ForEach(graph.nodes) { node in
                                nodeButton(node)
                            }
                        }
                        .scaleEffect(currentScale)
                        .offset(currentOffset)
                        .gesture(panGesture)
                        .simultaneousGesture(zoomGesture)
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
            .navigationBarTitleDisplayMode(.large)
            .background(AppTheme.surface)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                MetricPill(title: "品種", value: "\(library.activeVarieties.count)")
                MetricPill(title: "リンク", value: "\(library.parentLinks.count)")
                MetricPill(title: "表示", value: viewModel.direction.label)
            }

            TextField("起点品種を検索", text: $viewModel.rootSearchText)
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(AppTheme.field, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))

            ViewThatFits {
                HStack(spacing: 10) {
                    rootPicker
                    directionPicker
                }
                VStack(spacing: 10) {
                    rootPicker
                    directionPicker
                }
            }

            ViewThatFits {
                HStack {
                    Stepper("深さ \(viewModel.maxDepth)", value: $viewModel.maxDepth, in: 1...5)
                    Stepper("最大 \(viewModel.maxNodes)", value: $viewModel.maxNodes, in: 30...120, step: 10)
                }
                VStack(alignment: .leading) {
                    Stepper("深さ \(viewModel.maxDepth)", value: $viewModel.maxDepth, in: 1...5)
                    Stepper("最大 \(viewModel.maxNodes)", value: $viewModel.maxNodes, in: 30...120, step: 10)
                }
            }
            .font(.subheadline)

            HStack(spacing: 10) {
                Button {
                    viewModel.resetViewport()
                } label: {
                    Label("表示リセット", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
                CapsuleBadge(text: String(format: "ズーム %.1fx", Double(viewModel.zoomScale)), tint: AppTheme.muted)
            }
        }
        .cardSurface()
    }

    private var rootPicker: some View {
        Menu {
            Button("全体") {
                viewModel.rootID = ""
                viewModel.selectedNodeID = nil
                viewModel.resetViewport()
            }
            ForEach(filteredRootVarieties.prefix(80)) { variety in
                Button(variety.name) {
                    viewModel.rootID = variety.id
                    viewModel.selectedNodeID = variety.id
                    viewModel.resetViewport()
                }
            }
        } label: {
            Label(viewModel.rootID.isEmpty ? "起点: 全体" : "起点: \(library.varietyName(viewModel.rootID))", systemImage: "scope")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private var directionPicker: some View {
        Picker("表示方向", selection: $viewModel.direction) {
            ForEach(PedigreeDirection.allCases) { direction in
                Text(direction.label).tag(direction)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity)
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
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
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
                HStack(spacing: 10) {
                    Button {
                        library.selectedVarietyID = id
                        library.searchText = library.varietyName(id)
                        selectedTab = .library
                    } label: {
                        Label("図鑑", systemImage: "book.pages")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        reviewVM.reset(keeping: id)
                        selectedTab = .reviewEditor
                    } label: {
                        Label("評価", systemImage: "star")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Text("ノードをタップすると品種情報を確認できます。")
                    .foregroundStyle(AppTheme.muted)
            }
            ErrorBanner(message: viewModel.errorMessage)
        }
        .cardSurface()
    }

    private var filteredRootVarieties: [Variety] {
        let rows = library.activeVarieties
        return rows.filter { $0.matchesSearch(viewModel.rootSearchText) }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                viewModel.commitPan(value.translation)
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                viewModel.commitZoom(value)
            }
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
