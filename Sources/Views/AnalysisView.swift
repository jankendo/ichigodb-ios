import SwiftUI

private enum AnalysisMode: String, CaseIterable, Identifiable {
    case overview = "概要"
    case ranking = "ランキング"
    case discovery = "発見"

    var id: String { rawValue }
}

struct AnalysisView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @Binding var selectedTab: AppTab
    @State private var mode: AnalysisMode = .overview

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("分析", selection: $mode) {
                    ForEach(AnalysisMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        switch mode {
                        case .overview:
                            overview
                        case .ranking:
                            ranking
                        case .discovery:
                            discovery
                        }
                    }
                    .padding()
                    .frame(maxWidth: 920, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("いちご分析")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.surface)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandMark(size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text("Taste Board")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.ink)
                Text("食べた記録から、推し品種・傾向・次の一粒を見つけます。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
        }
        .cardSurface()
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: metricColumns, spacing: 10) {
                MetricPill(title: "評価数", value: "\(reviews.count)")
                MetricPill(title: "発見品種", value: "\(library.discoveredIDs.count)")
                MetricPill(title: "平均点", value: overallAverageText)
                MetricPill(title: "得意な軸", value: strongestTrait?.label ?? "-")
            }

            if reviews.isEmpty {
                emptyAnalysis
            } else {
                traitBars
                recentMomentum
                valueHighlights
            }
        }
    }

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 16) {
            analysisSection("総合ランキング", systemImage: "crown") {
                rankedVarieties(prefix: 12) { row in
                    RankingRow(
                        rank: row.rank,
                        title: row.variety.name,
                        subtitle: "\(row.count)件の評価",
                        value: String(format: "%.1f", row.average),
                        tint: row.rank <= 3 ? AppTheme.gold : AppTheme.strawberry
                    )
                }
            }

            analysisSection("項目別トップ", systemImage: "sparkles") {
                ForEach(traitLeaders) { leader in
                    RankingRow(
                        rank: nil,
                        title: leader.label,
                        subtitle: leader.variety?.name ?? "評価待ち",
                        value: leader.value.map { String(format: "%.1f", $0) } ?? "-",
                        tint: AppTheme.leaf
                    )
                }
            }
        }
    }

    private var discovery: some View {
        VStack(alignment: .leading, spacing: 16) {
            analysisSection("次に試したい候補", systemImage: "binoculars") {
                let rows = library.activeVarieties
                    .filter { !library.discoveredIDs.contains($0.id) }
                    .prefix(12)
                if rows.isEmpty {
                    Text("未発見品種はありません。図鑑コンプリートです。")
                        .foregroundStyle(AppTheme.muted)
                } else {
                    ForEach(Array(rows)) { variety in
                        Button {
                            library.searchText = variety.name
                            library.lens = .undiscovered
                            selectedTab = .library
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(variety.name)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(variety.originPrefecture ?? "産地未設定")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .foregroundStyle(AppTheme.strawberry)
                            }
                            .padding(12)
                            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            analysisSection("最近の発見", systemImage: "clock") {
                if recentReviews.isEmpty {
                    Text("まだ評価がありません。")
                        .foregroundStyle(AppTheme.muted)
                } else {
                    ForEach(recentReviews.prefix(8)) { review in
                        RankingRow(
                            rank: nil,
                            title: library.varietyName(review.varietyID),
                            subtitle: review.tastedDate,
                            value: "\(review.overall)",
                            tint: AppTheme.strawberry
                        )
                    }
                }
            }
        }
    }

    private var traitBars: some View {
        analysisSection("味の傾向", systemImage: "chart.bar") {
            ForEach(traitAverages) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.label)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(String(format: "%.1f", row.value))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.muted)
                    }
                    ProgressView(value: row.value, total: 5)
                        .tint(row.tint)
                }
            }
        }
    }

    private var recentMomentum: some View {
        analysisSection("最近の評価ペース", systemImage: "waveform.path.ecg") {
            ForEach(monthlyCounts) { row in
                HStack {
                    Text(row.month)
                        .font(.caption.weight(.semibold))
                        .frame(width: 62, alignment: .leading)
                    ProgressView(value: Double(row.count), total: Double(maxMonthlyCount))
                        .tint(AppTheme.strawberry)
                    Text("\(row.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }

    private var valueHighlights: some View {
        analysisSection("コスパメモ", systemImage: "yensign.circle") {
            let rows = reviews
                .filter { ($0.priceJPY ?? 0) > 0 }
                .sorted {
                    let left = Double($0.overall) / Double(max($0.priceJPY ?? 1, 1))
                    let right = Double($1.overall) / Double(max($1.priceJPY ?? 1, 1))
                    return left > right
                }
                .prefix(5)
            if rows.isEmpty {
                Text("価格を入れると、満足度の高い購入メモが見えてきます。")
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(Array(rows)) { review in
                    RankingRow(
                        rank: nil,
                        title: library.varietyName(review.varietyID),
                        subtitle: "\(review.priceJPY ?? 0)円 / \(review.tastedDate)",
                        value: "\(review.overall)",
                        tint: AppTheme.gold
                    )
                }
            }
        }
    }

    private func analysisSection<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .cardSurface()
    }

    private func rankedVarieties<Content: View>(prefix limit: Int, @ViewBuilder row: (VarietyRanking) -> Content) -> some View {
        let rows = varietyRankings.prefix(limit)
        return VStack(spacing: 10) {
            if rows.isEmpty {
                Text("評価を登録するとランキングが表示されます。")
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(Array(rows)) { item in
                    row(item)
                }
            }
        }
    }

    private var metricColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    }

    private var reviews: [Review] {
        library.activeReviews
    }

    private var recentReviews: [Review] {
        reviews.sorted { $0.tastedDate > $1.tastedDate }
    }

    private var overallAverageText: String {
        guard !reviews.isEmpty else { return "-" }
        let average = Double(reviews.map(\.overall).reduce(0, +)) / Double(reviews.count)
        return String(format: "%.1f", average)
    }

    private var traitAverages: [TraitAverage] {
        guard !reviews.isEmpty else { return [] }
        let count = Double(reviews.count)
        return [
            TraitAverage(label: "甘味", value: Double(reviews.map(\.sweetness).reduce(0, +)) / count, tint: AppTheme.strawberry),
            TraitAverage(label: "酸味", value: Double(reviews.map(\.sourness).reduce(0, +)) / count, tint: AppTheme.gold),
            TraitAverage(label: "香り", value: Double(reviews.map(\.aroma).reduce(0, +)) / count, tint: AppTheme.leaf),
            TraitAverage(label: "食感", value: Double(reviews.map(\.texture).reduce(0, +)) / count, tint: .blue),
            TraitAverage(label: "見た目", value: Double(reviews.map(\.appearance).reduce(0, +)) / count, tint: .purple)
        ]
    }

    private var strongestTrait: TraitAverage? {
        traitAverages.max { $0.value < $1.value }
    }

    private var traitLeaders: [TraitLeader] {
        [
            traitLeader("甘味", keyPath: \.sweetness),
            traitLeader("酸味", keyPath: \.sourness),
            traitLeader("香り", keyPath: \.aroma),
            traitLeader("食感", keyPath: \.texture),
            traitLeader("見た目", keyPath: \.appearance)
        ]
    }

    private func traitLeader(_ label: String, keyPath: KeyPath<Review, Int>) -> TraitLeader {
        let grouped = Dictionary(grouping: reviews, by: \.varietyID)
        let best = grouped.compactMap { id, rows -> (String, Double)? in
            guard !rows.isEmpty else { return nil }
            let average = Double(rows.map { $0[keyPath: keyPath] }.reduce(0, +)) / Double(rows.count)
            return (id, average)
        }
        .max { $0.1 < $1.1 }
        guard let best else { return TraitLeader(label: label, variety: nil, value: nil) }
        return TraitLeader(label: label, variety: library.activeVarieties.first(where: { $0.id == best.0 }), value: best.1)
    }

    private var varietyRankings: [VarietyRanking] {
        let grouped = Dictionary(grouping: reviews, by: \.varietyID)
        return grouped.compactMap { id, rows in
            guard let variety = library.activeVarieties.first(where: { $0.id == id }), !rows.isEmpty else { return nil }
            let average = Double(rows.map(\.overall).reduce(0, +)) / Double(rows.count)
            return (variety, average, rows.count)
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.2 > $1.2
        }
        .enumerated()
        .map { index, row in
            VarietyRanking(rank: index + 1, variety: row.0, average: row.1, count: row.2)
        }
    }

    private var monthlyCounts: [MonthlyReviewCount] {
        let grouped = Dictionary(grouping: reviews) { review in
            String(review.tastedDate.prefix(7))
        }
        return Array(grouped.map { MonthlyReviewCount(month: $0.key, count: $0.value.count) }
            .sorted { $0.month > $1.month }
            .prefix(6)
            .reversed())
    }

    private var maxMonthlyCount: Int {
        max(monthlyCounts.map { $0.count }.max() ?? 1, 1)
    }

    private var emptyAnalysis: some View {
        ContentUnavailableView(
            "まだ分析できる評価がありません",
            systemImage: "chart.xyaxis.line",
            description: Text("評価を登録すると、ランキングや味の傾向がここに育っていきます。")
        )
        .cardSurface()
    }
}

private struct VarietyRanking: Identifiable {
    var id: String { variety.id }
    var rank: Int
    var variety: Variety
    var average: Double
    var count: Int
}

private struct TraitAverage: Identifiable {
    var id: String { label }
    var label: String
    var value: Double
    var tint: Color
}

private struct TraitLeader: Identifiable {
    var id: String { label }
    var label: String
    var variety: Variety?
    var value: Double?
}

private struct MonthlyReviewCount: Identifiable {
    var id: String { month }
    var month: String
    var count: Int
}

private struct RankingRow: View {
    var rank: Int?
    var title: String
    var subtitle: String
    var value: String
    var tint: Color

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(tint, in: Circle())
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(tint)
        }
        .padding(12)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
