import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @ObservedObject var editorVM: VarietyEditorViewModel
    @ObservedObject var reviewVM: ReviewEditorViewModel
    @Binding var selectedTab: AppTab
    var onSignOut: (() async -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    quickActions
                    progressSection
                    recentSection
                    recommendationSection
                }
                .padding()
                .frame(maxWidth: 920)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.surface)
            .navigationTitle("IchigoDB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onSignOut {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await onSignOut() }
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .accessibilityLabel("ログアウト")
                    }
                }
            }
            .refreshable { await library.reload() }
            .scrollDismissesKeyboard(.interactively)
            .task {
                if library.varieties.isEmpty {
                    await library.reload()
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                BrandMark(size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日のいちごをすぐ記録")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.ink)
                    Text("\(library.activeVarieties.count)品種 / 評価 \(library.activeReviews.count)件 / \(library.networkState.label)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
            }

            Button {
                reviewVM.reset()
                selectedTab = .reviewEditor
            } label: {
                Label("食べ比べを開始", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .cardSurface()
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            actionCard(title: "図鑑を探す", value: "\(library.filteredVarieties.count)件", icon: "book.pages") {
                selectedTab = .library
            }
            actionCard(title: "品種登録", value: "重複確認つき", icon: "plus.square") {
                editorVM.reset()
                selectedTab = .varietyEditor
            }
            actionCard(title: "評価メモ", value: "\(reviewVM.queuedDrafts.count)件", icon: "tray.full") {
                selectedTab = .reviewEditor
            }
            actionCard(title: "分析", value: "ランキング", icon: "chart.xyaxis.line") {
                selectedTab = .analysis
            }
        }
    }

    private func actionCard(title: String, value: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.strawberry)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 104)
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line.opacity(0.55)))
        }
        .buttonStyle(.plain)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("図鑑進捗")
                    .font(.headline)
                Spacer()
                Text(library.progressText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppTheme.strawberry)
            }
            ProgressStrip(value: library.completionRate)
            HStack {
                MetricPill(title: "発見済み", value: "\(library.discoveredIDs.count)")
                MetricPill(title: "未発見", value: "\(max(0, library.activeVarieties.count - library.discoveredIDs.count))")
            }
        }
        .cardSurface()
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近の評価")
                    .font(.headline)
                Spacer()
                Button("すべて見る") {
                    selectedTab = .analysis
                }
                .font(.subheadline.weight(.semibold))
            }

            if library.recentReviewCards.isEmpty {
                Text("まだ評価がありません。食べ比べを開始するとここに履歴が並びます。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(library.recentReviewCards.prefix(3)) { card in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.varietyName)
                                .font(.subheadline.weight(.semibold))
                            Text(card.tastedDate)
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        CapsuleBadge(text: "\(card.overall)/10", tint: AppTheme.strawberry)
                    }
                    if card.id != library.recentReviewCards.prefix(3).last?.id {
                        Divider()
                    }
                }
            }
        }
        .cardSurface()
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("次に試したい候補")
                .font(.headline)
            ForEach(nextCandidates.prefix(5)) { variety in
                Button {
                    library.selectedVarietyID = variety.id
                    library.searchText = variety.name
                    selectedTab = .library
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: library.discoveredIDs.contains(variety.id) ? "star.circle" : "questionmark.circle")
                            .foregroundStyle(AppTheme.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(variety.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(variety.originPrefecture ?? "産地未設定")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .cardSurface()
    }

    private var nextCandidates: [Variety] {
        let highRated = library.activeVarieties
            .filter { library.averageOverall(for: $0.id) ?? 0 >= 8 }
            .sorted { (library.averageOverall(for: $0.id) ?? 0) > (library.averageOverall(for: $1.id) ?? 0) }
        let undiscovered = library.activeVarieties
            .filter { !library.discoveredIDs.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return Array((highRated + undiscovered).prefix(8))
    }
}
