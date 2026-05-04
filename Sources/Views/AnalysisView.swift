import SwiftUI

private enum AnalysisMode: String, CaseIterable, Identifiable {
    case overview = "概要"
    case reviews = "全レビュー"
    case ranking = "ランキング"
    case trends = "傾向"

    var id: String { rawValue }
}

private enum AnalysisReviewSort: String, CaseIterable, Identifiable {
    case latest = "新しい順"
    case score = "高評価順"
    case value = "コスパ順"

    var id: String { rawValue }
}

struct AnalysisView: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    @Binding var selectedTab: AppTab
    @State private var mode: AnalysisMode = .overview
    @State private var reviewSearchText = ""
    @State private var reviewMinimumOverall = 1
    @State private var reviewSort: AnalysisReviewSort = .latest

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
                        case .reviews:
                            reviewsBoard
                        case .ranking:
                            ranking
                        case .trends:
                            trends
                        }
                    }
                    .padding()
                    .frame(maxWidth: 940, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("いちご分析")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.surface)
            .keyboardDoneToolbar()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandMark(size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text("Taste Board")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.ink)
                Text("全レビューから推し品種、食べ比べ結果、次に試す候補をすぐ見つけます。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                selectedTab = .reviewEditor
            } label: {
                Image(systemName: "star.fill")
            }
            .buttonStyle(IconBadgeButtonStyle(tint: AppTheme.gold))
            .accessibilityLabel("評価を追加")
        }
        .cardSurface()
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: metricColumns, spacing: 10) {
                MetricPill(title: "評価数", value: "\(reviews.count)")
                MetricPill(title: "発見品種", value: "\(library.discoveredIDs.count)")
                MetricPill(title: "平均点", value: overallAverageText)
                MetricPill(title: "推し軸", value: strongestTrait?.label ?? "-")
            }

            if reviews.isEmpty {
                emptyAnalysis
            } else {
                insightStrip
                traitBars
                recentMomentum
            }
        }
    }

    private var reviewsBoard: some View {
        VStack(alignment: .leading, spacing: 16) {
            analysisSection("全レビューを探す", systemImage: "list.bullet.rectangle") {
                VStack(spacing: 12) {
                    TextField("品種名・メモ・購入場所", text: $reviewSearchText)
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(AppTheme.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))

                    ViewThatFits {
                        HStack(spacing: 10) {
                            reviewSortPicker
                            minimumScoreStepper
                        }
                        VStack(spacing: 10) {
                            reviewSortPicker
                            minimumScoreStepper
                        }
                    }
                }
            }

            analysisSection("\(filteredReviews.count)件のレビュー", systemImage: "star.bubble") {
                if filteredReviews.isEmpty {
                    Text("条件に合うレビューがありません。検索語やスコア条件を変えてください。")
                        .foregroundStyle(AppTheme.muted)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(filteredReviews.prefix(80))) { review in
                            AnalysisReviewCard(review: review) {
                                library.searchText = library.varietyName(review.varietyID)
                                library.lens = .discovered
                                selectedTab = .library
                            }
                        }
                    }
                }
            }
        }
    }

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 16) {
            analysisSection("総合ランキング", systemImage: "crown") {
                rankedVarieties(prefix: 15) { row in
                    RankingRow(
                        rank: row.rank,
                        title: row.variety.name,
                        subtitle: "\(row.count)件の評価 / 最新 \(row.latestDate)",
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

            valueHighlights
        }
    }

    private var trends: some View {
        VStack(alignment: .leading, spacing: 16) {
            recentMomentum

            analysisSection("県別の発見", systemImage: "map") {
                if prefectureRows.isEmpty {
                    Text("品種の産地情報が入ると、県別の傾向が見えてきます。")
                        .foregroundStyle(AppTheme.muted)
                } else {
                    ForEach(prefectureRows.prefix(10)) { row in
                        RankingRow(
                            rank: nil,
                            title: row.prefecture,
                            subtitle: "\(row.reviewCount)件 / \(row.varietyCount)品種",
                            value: String(format: "%.1f", row.average),
                            tint: AppTheme.leaf
                        )
                    }
                }
            }

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
                            .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var reviewSortPicker: some View {
        Picker("並び順", selection: $reviewSort) {
            ForEach(AnalysisReviewSort.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
    }

    private var minimumScoreStepper: some View {
        Stepper("総合 \(reviewMinimumOverall) 以上", value: $reviewMinimumOverall, in: 1...10)
            .padding(12)
            .background(AppTheme.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
    }

    private var insightStrip: some View {
        analysisSection("今の味覚メモ", systemImage: "heart.text.square") {
            VStack(alignment: .leading, spacing: 10) {
                if let top = varietyRankings.first {
                    InsightLine(
                        systemImage: "heart.fill",
                        title: "いまの推し",
                        value: "\(top.variety.name) / 平均 \(String(format: "%.1f", top.average))"
                    )
                }
                if let latest = recentReviews.first {
                    InsightLine(
                        systemImage: "clock",
                        title: "最新レビュー",
                        value: "\(library.varietyName(latest.varietyID)) / \(latest.tastedDate)"
                    )
                }
                if let value = valueScoreRows.first {
                    InsightLine(
                        systemImage: "yensign.circle",
                        title: "コスパ注目",
                        value: "\(library.varietyName(value.varietyID)) / \(value.priceJPY ?? 0)円"
                    )
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
        analysisSection("評価ペース", systemImage: "waveform.path.ecg") {
            if monthlyCounts.isEmpty {
                Text("評価が増えると月別ペースを表示します。")
                    .foregroundStyle(AppTheme.muted)
            } else {
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
    }

    private var valueHighlights: some View {
        analysisSection("コスパランキング", systemImage: "yensign.circle") {
            let rows = valueScoreRows.prefix(8)
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

    private func rankedVarieties<Content: View>(prefix limit: Int, @ViewBuilder row: @escaping (VarietyRanking) -> Content) -> some View {
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
        reviews.sorted {
            if $0.tastedDate != $1.tastedDate {
                return $0.tastedDate > $1.tastedDate
            }
            return ($0.updatedAt ?? $0.createdAt ?? "") > ($1.updatedAt ?? $1.createdAt ?? "")
        }
    }

    private var filteredReviews: [Review] {
        let filtered = reviews.filter { review in
            review.overall >= reviewMinimumOverall && reviewMatchesSearch(review)
        }
        switch reviewSort {
        case .latest:
            return filtered.sorted {
                if $0.tastedDate != $1.tastedDate {
                    return $0.tastedDate > $1.tastedDate
                }
                return $0.overall > $1.overall
            }
        case .score:
            return filtered.sorted {
                if $0.overall != $1.overall {
                    return $0.overall > $1.overall
                }
                return $0.tastedDate > $1.tastedDate
            }
        case .value:
            return filtered.sorted { valueScore($0) > valueScore($1) }
        }
    }

    private func reviewMatchesSearch(_ review: Review) -> Bool {
        let query = reviewSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let variety = library.activeVarieties.first(where: { $0.id == review.varietyID })
        if variety?.matchesSearch(query) == true {
            return true
        }
        let text = [review.comment, review.purchasePlace, review.tastedDate]
            .compactMap { $0 }
            .joined(separator: " ")
        return SearchIndex.matches(query: query, in: text)
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
        let rows: [(variety: Variety, average: Double, count: Int, latestDate: String)] = grouped.compactMap { id, rows in
            guard let variety = library.activeVarieties.first(where: { $0.id == id }), !rows.isEmpty else { return nil }
            let average = Double(rows.map(\.overall).reduce(0, +)) / Double(rows.count)
            let latest = rows.map(\.tastedDate).max() ?? "-"
            return (variety, average, rows.count, latest)
        }
        return rows.sorted {
            if $0.average != $1.average { return $0.average > $1.average }
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.latestDate > $1.latestDate
        }
        .enumerated()
        .map { index, row in
            VarietyRanking(rank: index + 1, variety: row.variety, average: row.average, count: row.count, latestDate: row.latestDate)
        }
    }

    private var monthlyCounts: [MonthlyReviewCount] {
        let grouped = Dictionary(grouping: reviews) { review in
            String(review.tastedDate.prefix(7))
        }
        return Array(grouped.map { MonthlyReviewCount(month: $0.key, count: $0.value.count) }
            .sorted { $0.month > $1.month }
            .prefix(8)
            .reversed())
    }

    private var maxMonthlyCount: Int {
        max(monthlyCounts.map { $0.count }.max() ?? 1, 1)
    }

    private var valueScoreRows: [Review] {
        reviews
            .filter { ($0.priceJPY ?? 0) > 0 }
            .sorted { valueScore($0) > valueScore($1) }
    }

    private func valueScore(_ review: Review) -> Double {
        Double(review.overall) / Double(max(review.priceJPY ?? 1, 1))
    }

    private var prefectureRows: [PrefectureAnalysisRow] {
        let grouped = Dictionary(grouping: reviews) { review -> String in
            library.activeVarieties.first(where: { $0.id == review.varietyID })?.originPrefecture ?? "産地未設定"
        }
        return grouped.compactMap { prefecture, rows in
            guard !rows.isEmpty else { return nil }
            let average = Double(rows.map(\.overall).reduce(0, +)) / Double(rows.count)
            let varietyCount = Set(rows.map(\.varietyID)).count
            return PrefectureAnalysisRow(prefecture: prefecture, reviewCount: rows.count, varietyCount: varietyCount, average: average)
        }
        .sorted {
            if $0.reviewCount != $1.reviewCount {
                return $0.reviewCount > $1.reviewCount
            }
            return $0.average > $1.average
        }
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
    var latestDate: String
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

private struct PrefectureAnalysisRow: Identifiable {
    var id: String { prefecture }
    var prefecture: String
    var reviewCount: Int
    var varietyCount: Int
    var average: Double
}

private struct InsightLine: View {
    var systemImage: String
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.strawberry)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct AnalysisReviewCard: View {
    @EnvironmentObject private var library: VarietyLibraryViewModel
    var review: Review
    var openVariety: () -> Void

    var body: some View {
        Button(action: openVariety) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    if let source = thumbnailSource {
                        AsyncVarietyImage(
                            image: library.loadedImage(for: source),
                            url: library.imageURL(for: source),
                            height: 72,
                            contentMode: .fit
                        )
                        .frame(width: 72)
                        .task(id: source.cacheKey) {
                            await library.ensureImage(for: source)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(library.varietyName(review.varietyID))
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(review.tastedDate)
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    CapsuleBadge(text: "\(review.overall)/10", tint: AppTheme.strawberry)
                }

                HStack(spacing: 6) {
                    score("甘", review.sweetness)
                    score("酸", review.sourness)
                    score("香", review.aroma)
                    score("食", review.texture)
                    score("見", review.appearance)
                }

                if let place = review.purchasePlace, !place.isEmpty {
                    Label(place, systemImage: "bag")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                if let price = review.priceJPY, price > 0 {
                    Label("\(price)円", systemImage: "yensign.circle")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                if let comment = review.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(3)
                }
            }
            .padding(12)
            .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.7)))
        }
        .buttonStyle(.plain)
    }

    private var thumbnailSource: VarietyThumbnailSource? {
        library.thumbnailSource(for: review.varietyID)
    }

    private func score(_ label: String, _ value: Int) -> some View {
        Text("\(label)\(value)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.card, in: Capsule())
            .foregroundStyle(AppTheme.ink)
    }
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
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
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
