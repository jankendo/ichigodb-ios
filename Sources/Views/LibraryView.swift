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
            if let selectedID = library.selectedVarietyID {
                splitSelection = selectedID
            }
            if splitSelection == nil {
                splitSelection = library.filteredVarieties.first?.id
            }
        }
        .onChange(of: library.selectedVarietyID) { id in
            if let id {
                splitSelection = id
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
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $library.searchText, prompt: "品種名・特徴")
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
            .navigationBarTitleDisplayMode(.inline)
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
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                BrandMark(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("品種図鑑")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("\(library.filteredVarieties.count)件 / \(library.activeVarieties.count)品種 / 進捗 \(library.progressText)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                Spacer(minLength: 6)
                Button {
                    editorVM.reset()
                    selectedTab = .varietyEditor
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(IconBadgeButtonStyle(tint: AppTheme.strawberry))
                .accessibilityLabel("品種を登録")

                Button {
                    reviewVM.reset()
                    selectedTab = .reviewEditor
                } label: {
                    Image(systemName: "star.fill")
                }
                .buttonStyle(IconBadgeButtonStyle(tint: AppTheme.gold))
                .accessibilityLabel("評価を追加")
            }

            ProgressStrip(value: library.completionRate)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LibraryLens.allCases) { lens in
                        LensChip(
                            title: lens.rawValue,
                            systemImage: lens.systemImage,
                            selected: library.lens == lens
                        ) {
                            library.lens = lens
                        }
                    }
                }
                .padding(.horizontal, 1)
            }

            ViewThatFits {
                HStack(spacing: 8) {
                    filterMenu
                    sortMenu
                }
                VStack(spacing: 8) {
                    filterMenu
                    sortMenu
                }
            }

            ErrorBanner(message: library.errorMessage)
        }
        .padding(.horizontal, 14)
        .padding(.top, 7)
        .padding(.bottom, 8)
        .background(AppTheme.surface)
    }

    private var filterMenu: some View {
        Menu {
            Section("発見状態") {
                ForEach(DiscoveryFilter.allCases) { filter in
                    Button(filter.rawValue) { library.discoveryFilter = filter }
                }
            }
            Section("都道府県") {
                Button("すべて") { library.prefectureFilter = "" }
                ForEach(Prefecture.all, id: \.self) { prefecture in
                    Button(prefecture) { library.prefectureFilter = prefecture }
                }
            }
            if !library.availableTags.isEmpty {
                Section("タグ") {
                    Button("すべて") { library.selectedTag = "" }
                    ForEach(library.availableTags, id: \.self) { tag in
                        Button(tag) { library.selectedTag = tag }
                    }
                }
            }
        } label: {
            Label(filterSummary, systemImage: "line.3.horizontal.decrease.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CompactControlButtonStyle())
    }

    private var sortMenu: some View {
        Menu {
            ForEach(VarietySortOption.allCases) { option in
                Button(option.rawValue) { library.sortOption = option }
            }
        } label: {
            Label("並び: \(sortSummary)", systemImage: "arrow.up.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CompactControlButtonStyle())
    }

    private var filterSummary: String {
        var parts = [library.discoveryFilter.rawValue]
        if !library.prefectureFilter.isEmpty {
            parts.append(library.prefectureFilter)
        }
        if !library.selectedTag.isEmpty {
            parts.append("#\(library.selectedTag)")
        }
        return parts.joined(separator: " / ")
    }

    private var sortSummary: String {
        switch library.lens {
        case .all:
            return library.sortOption.rawValue
        case .discovered, .recent:
            return "最新評価"
        case .topRated:
            return "平均点"
        case .undiscovered:
            return "名前"
        }
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
        HStack(spacing: 12) {
            AsyncVarietyImage(
                image: library.loadedImage(bucket: "variety-images", path: primaryImage?.storagePath),
                url: library.imageURL(for: primaryImage),
                height: 84,
                contentMode: .fit
            )
                .frame(width: 84)
                .task(id: primaryImage?.storagePath) {
                    guard let primaryImage else { return }
                    await library.ensureImage(bucket: "variety-images", path: primaryImage.storagePath)
                }
                .accessibilityLabel("\(variety.name)の画像")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(variety.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Spacer()
                    if library.discoveredIDs.contains(variety.id) {
                        CapsuleBadge(text: "発見済み", tint: AppTheme.leaf)
                    }
                }
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
                if let average = library.averageOverall(for: variety.id) {
                    HStack(spacing: 8) {
                        Label(String(format: "平均 %.1f/10", average), systemImage: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(AppTheme.strawberry)
                        if let latest = library.latestReview(for: variety.id) {
                            Text("最新 \(latest.tastedDate)")
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
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

    private var primaryImage: VarietyImage? {
        library.primaryImage(for: variety.id)
    }

    private var summary: String {
        variety.characteristicsSummary
            ?? variety.description
            ?? variety.developer
            ?? "特徴は未登録です。"
    }
}

private struct ReviewHistoryRow: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    var review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.tastedDate)
                        .font(.headline)
                    if let comment = review.comment, !comment.isEmpty {
                        Text(comment)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                            .lineLimit(3)
                    }
                }
                Spacer()
                CapsuleBadge(text: "\(review.overall)/10", tint: AppTheme.strawberry)
            }

            HStack(spacing: 6) {
                miniScore("甘", review.sweetness)
                miniScore("酸", review.sourness)
                miniScore("香", review.aroma)
                miniScore("食", review.texture)
                miniScore("見", review.appearance)
            }

            if !library.reviewImages(for: review.id).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(library.reviewImages(for: review.id)) { image in
                            AsyncVarietyImage(
                                image: library.loadedImage(bucket: "review-images", path: image.storagePath),
                                url: library.imageURL(bucket: "review-images", path: image.storagePath),
                                height: 64,
                                contentMode: .fit
                            )
                            .frame(width: 64)
                            .task(id: image.storagePath) {
                                await library.ensureImage(bucket: "review-images", path: image.storagePath)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func miniScore(_ label: String, _ value: Int) -> some View {
        Text("\(label)\(value)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.elevated, in: Capsule())
            .foregroundStyle(AppTheme.ink)
    }
}

private struct VarietyImageGallery: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    var varietyID: String
    var height: CGFloat

    var body: some View {
        Group {
            if images.isEmpty {
                AsyncVarietyImage(height: height)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(images) { image in
                            ZStack(alignment: .topLeading) {
                                AsyncVarietyImage(
                                    image: library.loadedImage(bucket: "variety-images", path: image.storagePath),
                                    url: library.imageURL(bucket: "variety-images", path: image.storagePath),
                                    height: height,
                                    contentMode: .fit
                                )
                                .frame(width: min(520, max(260, height * 1.28)))
                                .task(id: image.storagePath) {
                                    await library.ensureImage(bucket: "variety-images", path: image.storagePath)
                                }
                                if image.isPrimary {
                                    CapsuleBadge(text: "メイン", tint: AppTheme.strawberry)
                                        .padding(10)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var images: [VarietyImage] {
        library.images(for: varietyID)
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
                VarietyImageGallery(varietyID: variety.id, height: horizontalSizeClass == .regular ? 320 : 230)

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

                reviewSummary

                if let text = variety.characteristicsSummary ?? variety.description, !text.isEmpty {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(AppTheme.ink)
                        .cardSurface()
                }

                detailRows

                relationRows

                reviewTimeline
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
            labeled("別名", variety.aliasNames.isEmpty ? nil : variety.aliasNames.joined(separator: ", "))
            labeled("育成者", variety.developer)
            labeled("登録年", variety.registeredYear.map(String.init))
            labeled("果皮色", variety.skinColor)
            labeled("果肉色", variety.fleshColor)
            labeled("タグ", variety.tags.isEmpty ? nil : variety.tags.joined(separator: ", "))
        }
        .cardSurface()
    }

    private var relationRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交配リンク")
                .font(.headline)
            relationGroup(title: "親品種", rows: library.parents(for: variety.id))
            relationGroup(title: "子品種", rows: library.children(for: variety.id))
        }
        .cardSurface()
    }

    private func relationGroup(title: String, rows: [Variety]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            if rows.isEmpty {
                Text("未登録")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(rows) { row in
                            Button {
                                library.selectedVarietyID = row.id
                                library.searchText = row.name
                            } label: {
                                CapsuleBadge(text: row.name, tint: AppTheme.leaf)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var reviewSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("評価サマリ")
                    .font(.headline)
                Spacer()
                if let average = library.averageOverall(for: variety.id) {
                    CapsuleBadge(text: String(format: "平均 %.1f/10", average), tint: AppTheme.strawberry)
                } else {
                    CapsuleBadge(text: "評価なし", tint: AppTheme.muted)
                }
            }

            if library.reviews(for: variety.id).isEmpty {
                Text("まだ評価がありません。下の「評価する」から最初の記録を追加できます。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(library.tasteAverages(for: variety.id), id: \.0) { label, value in
                        HStack {
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .frame(width: 44, alignment: .leading)
                            ProgressView(value: value, total: 5)
                                .tint(AppTheme.strawberry)
                            Text(String(format: "%.1f", value))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.muted)
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .cardSurface()
    }

    private var reviewTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("評価履歴")
                .font(.headline)

            if displayedReviews.isEmpty {
                Text("ユーザ評価はまだ登録されていません。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(displayedReviews) { review in
                    ReviewHistoryRow(review: review)
                    if review.id != displayedReviews.last?.id {
                        Divider()
                    }
                }
            }
        }
        .cardSurface()
    }

    private var displayedReviews: [Review] {
        Array(library.reviews(for: variety.id).prefix(8))
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
