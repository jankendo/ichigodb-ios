import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var editorVM: VarietyEditorViewModel
    @ObservedObject var reviewVM: ReviewEditorViewModel
    @Binding var selectedTab: AppTab
    @State private var splitSelection: String?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .task {
            if splitSelection == nil {
                splitSelection = library.filteredVarieties.first?.id
            }
        }
        .onChange(of: library.filteredVarieties.map(\.id)) { ids in
            if let splitSelection, ids.contains(splitSelection) {
                return
            }
            splitSelection = ids.first
        }
    }

    private var compactLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                compactList
            }
            .navigationTitle("品種図鑑")
            .searchable(text: $library.searchText, prompt: "品種名・登録番号・特徴で検索")
            .toolbar { refreshToolbar }
            .overlay { loadingOverlay }
            .navigationDestination(for: Variety.self) { variety in
                detail(for: variety)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                header
                splitList
            }
            .navigationTitle("品種図鑑")
            .searchable(text: $library.searchText, prompt: "検索")
            .toolbar { refreshToolbar }
            .overlay { loadingOverlay }
        } detail: {
            if let selected = selectedVariety {
                NavigationStack {
                    detail(for: selected)
                }
            } else {
                ContentUnavailableView(
                    "品種を選択",
                    systemImage: "book.pages",
                    description: Text("左の一覧から品種を選ぶと詳細を表示します。")
                )
            }
        }
    }

    private var selectedVariety: Variety? {
        guard let splitSelection else { return library.filteredVarieties.first }
        return library.varieties.first(where: { $0.id == splitSelection })
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                MetricPill(title: "図鑑進捗", value: library.progressText)
                MetricPill(title: "登録品種", value: "\(library.varieties.count)")
                MetricPill(title: "評価", value: "\(library.reviews.count)")
            }

            VStack(spacing: 10) {
                Picker("状態", selection: $library.discoveryFilter) {
                    ForEach(DiscoveryFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Menu {
                    Button("すべて") { library.prefectureFilter = "" }
                    ForEach(Prefecture.all, id: \.self) { prefecture in
                        Button(prefecture) { library.prefectureFilter = prefecture }
                    }
                } label: {
                    Label(library.prefectureFilter.isEmpty ? "都道府県: すべて" : library.prefectureFilter, systemImage: "line.3.horizontal.decrease.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                ErrorBanner(message: library.errorMessage)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.background)
    }

    private var compactList: some View {
        List {
            if library.filteredVarieties.isEmpty {
                emptyState
                    .listRowSeparator(.hidden)
            } else {
                ForEach(library.filteredVarieties) { variety in
                    NavigationLink(value: variety) {
                        VarietyRow(variety: variety, selected: false)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await library.reload() }
    }

    private var splitList: some View {
        List {
            if library.filteredVarieties.isEmpty {
                emptyState
                    .listRowSeparator(.hidden)
            } else {
                ForEach(library.filteredVarieties) { variety in
                    Button {
                        splitSelection = variety.id
                    } label: {
                        VarietyRow(variety: variety, selected: splitSelection == variety.id)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await library.reload() }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "該当する品種がありません",
            systemImage: "magnifyingglass",
            description: Text("検索語やフィルタを変えてください。")
        )
        .padding(.vertical, 48)
    }

    private var loadingOverlay: some View {
        Group {
            if library.isLoading && library.varieties.isEmpty {
                ProgressView("読み込み中")
                    .padding(18)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ToolbarContentBuilder
    private var refreshToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await library.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(library.isLoading)
            .accessibilityLabel("再読み込み")
        }
    }

    private func detail(for variety: Variety) -> some View {
        VarietyDetailView(
            variety: variety,
            onEdit: {
                editorVM.edit(variety, parentLinks: library.parentLinks)
                selectedTab = .varietyEditor
            },
            onReview: {
                reviewVM.reset(keeping: variety.id)
                selectedTab = .reviewEditor
            }
        )
    }
}

private struct VarietyRow: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    var variety: Variety
    var selected: Bool

    var body: some View {
        HStack(spacing: 14) {
            AsyncVarietyImage(url: library.imageURL(for: library.primaryImage(for: variety.id)), height: 92)
                .frame(width: 92)
                .task {
                    if let image = library.primaryImage(for: variety.id) {
                        await library.ensureSignedURL(for: image)
                    }
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(variety.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    if library.discoveredIDs.contains(variety.id) {
                        CapsuleBadge(text: "発見済み", tint: AppTheme.leaf)
                    }
                }
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
                HStack {
                    Label("\(library.reviewCount(for: variety.id))件", systemImage: "star")
                    if let prefecture = variety.originPrefecture {
                        Label(prefecture, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            }
        }
        .cardSurface()
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? AppTheme.strawberry : .clear, lineWidth: 2)
        )
    }

    private var summary: String {
        variety.characteristicsSummary
            ?? variety.description
            ?? variety.developer
            ?? "特徴は未登録です。"
    }
}

struct VarietyDetailView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var variety: Variety
    var onEdit: () -> Void
    var onReview: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncVarietyImage(url: library.imageURL(for: library.primaryImage(for: variety.id)), height: horizontalSizeClass == .regular ? 320 : 230)
                    .task {
                        if let image = library.primaryImage(for: variety.id) {
                            await library.ensureSignedURL(for: image)
                        }
                    }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(variety.name)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.ink)
                        Text(variety.originPrefecture ?? "産地未設定")
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    CapsuleBadge(text: library.discoveredIDs.contains(variety.id) ? "発見済み" : "未発見", tint: library.discoveredIDs.contains(variety.id) ? AppTheme.leaf : AppTheme.muted)
                }

                LazyVGrid(columns: metricColumns, spacing: 10) {
                    MetricPill(title: "評価数", value: "\(library.reviewCount(for: variety.id))")
                    MetricPill(title: "糖度", value: IchigoFormat.brix(min: variety.brixMin, max: variety.brixMax))
                    MetricPill(title: "酸味", value: variety.acidityLevel.label)
                    MetricPill(title: "収穫", value: "\(IchigoFormat.month(variety.harvestStartMonth)) - \(IchigoFormat.month(variety.harvestEndMonth))")
                }

                if let latest = library.latestReview(for: variety.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最新評価")
                            .font(.headline)
                        Text("\(latest.tastedDate) / 総合 \(latest.overall)/10")
                        if let comment = latest.comment, !comment.isEmpty {
                            Text(comment)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .cardSurface()
                }

                if let text = variety.characteristicsSummary ?? variety.description, !text.isEmpty {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(AppTheme.ink)
                        .cardSurface()
                }

                detailRows
            }
            .padding()
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button("評価する", action: onReview)
                    .buttonStyle(PrimaryButtonStyle())
                Button("編集", action: onEdit)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding()
            .background(.thinMaterial)
        }
        .navigationTitle(variety.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metricColumns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("登録情報")
                .font(.headline)
            labeled("登録番号", variety.registrationNumber)
            labeled("出願番号", variety.applicationNumber)
            labeled("育成者", variety.developer)
            labeled("登録年", variety.registeredYear.map(String.init))
            labeled("果皮色", variety.skinColor)
            labeled("果肉色", variety.fleshColor)
            labeled("タグ", variety.tags.isEmpty ? nil : variety.tags.joined(separator: ", "))
        }
        .cardSurface()
    }

    private func labeled(_ title: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(AppTheme.muted)
                .frame(width: 86, alignment: .leading)
            Text(value?.isEmpty == false ? value! : "-")
                .foregroundStyle(AppTheme.ink)
            Spacer()
        }
        .font(.subheadline)
    }
}
