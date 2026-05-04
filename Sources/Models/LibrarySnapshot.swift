import Foundation

struct ReviewStats: Codable, Equatable, Hashable {
    var reviewCount: Int
    var averageOverall: Double?
    var latestReviewDate: String?
    var latestReviewID: String?
    var sweetnessAverage: Double?
    var sournessAverage: Double?
    var aromaAverage: Double?
    var textureAverage: Double?
    var appearanceAverage: Double?

    static let empty = ReviewStats(
        reviewCount: 0,
        averageOverall: nil,
        latestReviewDate: nil,
        latestReviewID: nil,
        sweetnessAverage: nil,
        sournessAverage: nil,
        aromaAverage: nil,
        textureAverage: nil,
        appearanceAverage: nil
    )
}

struct VarietyLibraryCard: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var aliasNames: [String]
    var originPrefecture: String?
    var tags: [String]
    var deletedAt: String?
    var updatedAt: String?
    var reviewCount: Int
    var averageOverall: Double?
    var latestReviewDate: String?
    var latestReviewID: String?
    var thumbnailBucket: String?
    var thumbnailPath: String?
    var parentCount: Int
    var childCount: Int
    var searchBlob: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case aliasNames = "alias_names"
        case originPrefecture = "origin_prefecture"
        case tags
        case deletedAt = "deleted_at"
        case updatedAt = "updated_at"
        case reviewCount = "review_count"
        case averageOverall = "average_overall"
        case latestReviewDate = "latest_review_date"
        case latestReviewID = "latest_review_id"
        case thumbnailBucket = "thumbnail_bucket"
        case thumbnailPath = "thumbnail_path"
        case parentCount = "parent_count"
        case childCount = "child_count"
        case searchBlob = "search_blob"
    }

    init(
        id: String,
        name: String,
        aliasNames: [String] = [],
        originPrefecture: String? = nil,
        tags: [String] = [],
        deletedAt: String? = nil,
        updatedAt: String? = nil,
        reviewCount: Int = 0,
        averageOverall: Double? = nil,
        latestReviewDate: String? = nil,
        latestReviewID: String? = nil,
        thumbnailBucket: String? = nil,
        thumbnailPath: String? = nil,
        parentCount: Int = 0,
        childCount: Int = 0,
        searchBlob: String = ""
    ) {
        self.id = id
        self.name = name
        self.aliasNames = aliasNames
        self.originPrefecture = originPrefecture
        self.tags = tags
        self.deletedAt = deletedAt
        self.updatedAt = updatedAt
        self.reviewCount = reviewCount
        self.averageOverall = averageOverall
        self.latestReviewDate = latestReviewDate
        self.latestReviewID = latestReviewID
        self.thumbnailBucket = thumbnailBucket
        self.thumbnailPath = thumbnailPath
        self.parentCount = parentCount
        self.childCount = childCount
        self.searchBlob = searchBlob
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aliasNames = try container.decodeIfPresent([String].self, forKey: .aliasNames) ?? []
        originPrefecture = try container.decodeIfPresent(String.self, forKey: .originPrefecture)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        averageOverall = try container.decodeFlexibleDoubleIfPresent(forKey: .averageOverall)
        latestReviewDate = try container.decodeIfPresent(String.self, forKey: .latestReviewDate)
        latestReviewID = try container.decodeIfPresent(String.self, forKey: .latestReviewID)
        thumbnailBucket = try container.decodeIfPresent(String.self, forKey: .thumbnailBucket)
        thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        parentCount = try container.decodeIfPresent(Int.self, forKey: .parentCount) ?? 0
        childCount = try container.decodeIfPresent(Int.self, forKey: .childCount) ?? 0
        searchBlob = (try? container.decode(String.self, forKey: .searchBlob)) ?? ""
        if searchBlob.isEmpty {
            searchBlob = ([name, originPrefecture].compactMap { $0 } + aliasNames + tags)
                .joined(separator: " ")
                .normalizedSearchText
        }
    }

    init(variety: Variety, stats: ReviewStats, thumbnailSource: VarietyThumbnailSource?, parentCount: Int, childCount: Int) {
        self.init(
            id: variety.id,
            name: variety.name,
            aliasNames: variety.aliasNames,
            originPrefecture: variety.originPrefecture,
            tags: variety.tags,
            deletedAt: variety.deletedAt,
            updatedAt: variety.updatedAt,
            reviewCount: stats.reviewCount,
            averageOverall: stats.averageOverall,
            latestReviewDate: stats.latestReviewDate,
            latestReviewID: stats.latestReviewID,
            thumbnailBucket: thumbnailSource?.bucket,
            thumbnailPath: thumbnailSource?.path,
            parentCount: parentCount,
            childCount: childCount,
            searchBlob: variety.searchBlob
        )
    }

    var thumbnailSource: VarietyThumbnailSource? {
        guard let thumbnailBucket, let thumbnailPath else { return nil }
        return VarietyThumbnailSource(bucket: thumbnailBucket, path: thumbnailPath)
    }

    func matchesSearch(_ query: String) -> Bool {
        let normalized = query.normalizedSearchText
        guard !normalized.isEmpty else { return true }
        let compactBlob = searchBlob.compactSearchText
        return normalized.searchTokens.allSatisfy { token in
            searchBlob.contains(token) || compactBlob.contains(token.compactSearchText)
        }
    }
}

struct LibrarySnapshot: Codable, Equatable {
    var cards: [VarietyLibraryCard]
    var discoveredIDs: Set<String>
    var reviewStatsByVarietyID: [String: ReviewStats]
    var thumbnailSourceByVarietyID: [String: VarietyThumbnailSource]
    var latestReviewByVarietyID: [String: Review]
    var reviewsByVarietyID: [String: [Review]]
    var reviewImagesByReviewID: [String: [ReviewImage]]
    var varietyImagesByVarietyID: [String: [VarietyImage]]
    var parentsByVarietyID: [String: [String]]
    var childrenByVarietyID: [String: [String]]
    var availableTags: [String]
    var generatedAt: Date

    static let empty = LibrarySnapshot(
        cards: [],
        discoveredIDs: [],
        reviewStatsByVarietyID: [:],
        thumbnailSourceByVarietyID: [:],
        latestReviewByVarietyID: [:],
        reviewsByVarietyID: [:],
        reviewImagesByReviewID: [:],
        varietyImagesByVarietyID: [:],
        parentsByVarietyID: [:],
        childrenByVarietyID: [:],
        availableTags: [],
        generatedAt: Date()
    )

    static func make(
        varieties: [Variety],
        reviews: [Review],
        parentLinks: [VarietyParentLink],
        varietyImages: [VarietyImage],
        reviewImages: [ReviewImage]
    ) -> LibrarySnapshot {
        let activeReviews = reviews.filter { $0.deletedAt == nil }
        let reviewsByVarietyID = Dictionary(grouping: activeReviews) { $0.varietyID }
            .mapValues { rows in rows.sorted { lhs, rhs in lhs.tastedDate == rhs.tastedDate ? (lhs.createdAt ?? "") > (rhs.createdAt ?? "") : lhs.tastedDate > rhs.tastedDate } }
        let reviewImagesByReviewID = Dictionary(grouping: reviewImages) { $0.reviewID }
            .mapValues { rows in rows.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") } }
        let varietyImagesByVarietyID = Dictionary(grouping: varietyImages) { $0.varietyID }
            .mapValues { rows in
                rows.sorted {
                    if $0.isPrimary != $1.isPrimary {
                        return $0.isPrimary && !$1.isPrimary
                    }
                    return ($0.createdAt ?? "") > ($1.createdAt ?? "")
                }
            }

        let parentsByVarietyID = Dictionary(grouping: parentLinks, by: \.childVarietyID)
            .mapValues { rows in rows.sorted { ($0.parentOrder ?? 0) < ($1.parentOrder ?? 0) }.map(\.parentVarietyID) }
        let childrenByVarietyID = Dictionary(grouping: parentLinks, by: \.parentVarietyID)
            .mapValues { rows in rows.sorted { ($0.parentOrder ?? 0) < ($1.parentOrder ?? 0) }.map(\.childVarietyID) }

        var latestReviewByVarietyID = [String: Review]()
        var reviewStatsByVarietyID = [String: ReviewStats]()
        var thumbnailSourceByVarietyID = [String: VarietyThumbnailSource]()

        for variety in varieties {
            let rows = reviewsByVarietyID[variety.id] ?? []
            let latest = rows.first
            if let latest {
                latestReviewByVarietyID[variety.id] = latest
            }
            if !rows.isEmpty {
                let count = Double(rows.count)
                reviewStatsByVarietyID[variety.id] = ReviewStats(
                    reviewCount: rows.count,
                    averageOverall: Double(rows.map(\.overall).reduce(0, +)) / count,
                    latestReviewDate: latest?.tastedDate,
                    latestReviewID: latest?.id,
                    sweetnessAverage: Double(rows.map(\.sweetness).reduce(0, +)) / count,
                    sournessAverage: Double(rows.map(\.sourness).reduce(0, +)) / count,
                    aromaAverage: Double(rows.map(\.aroma).reduce(0, +)) / count,
                    textureAverage: Double(rows.map(\.texture).reduce(0, +)) / count,
                    appearanceAverage: Double(rows.map(\.appearance).reduce(0, +)) / count
                )
            }

            let latestReviewImage = rows.lazy.compactMap { review in
                reviewImagesByReviewID[review.id]?.first
            }.first
            if let image = latestReviewImage {
                thumbnailSourceByVarietyID[variety.id] = VarietyThumbnailSource(bucket: "review-images", path: image.storagePath)
            } else if let image = varietyImagesByVarietyID[variety.id]?.first {
                thumbnailSourceByVarietyID[variety.id] = VarietyThumbnailSource(bucket: "variety-images", path: image.storagePath)
            }
        }

        let cards = varieties.map { variety in
            VarietyLibraryCard(
                variety: variety,
                stats: reviewStatsByVarietyID[variety.id] ?? .empty,
                thumbnailSource: thumbnailSourceByVarietyID[variety.id],
                parentCount: parentsByVarietyID[variety.id]?.count ?? 0,
                childCount: childrenByVarietyID[variety.id]?.count ?? 0
            )
        }

        return LibrarySnapshot(
            cards: cards,
            discoveredIDs: Set(activeReviews.map(\.varietyID)),
            reviewStatsByVarietyID: reviewStatsByVarietyID,
            thumbnailSourceByVarietyID: thumbnailSourceByVarietyID,
            latestReviewByVarietyID: latestReviewByVarietyID,
            reviewsByVarietyID: reviewsByVarietyID,
            reviewImagesByReviewID: reviewImagesByReviewID,
            varietyImagesByVarietyID: varietyImagesByVarietyID,
            parentsByVarietyID: parentsByVarietyID,
            childrenByVarietyID: childrenByVarietyID,
            availableTags: Array(Set(varieties.filter { $0.deletedAt == nil }.flatMap(\.tags))).sorted(),
            generatedAt: Date()
        )
    }
}

struct ReviewAnalysisCard: Identifiable, Codable, Hashable {
    var id: String
    var varietyID: String
    var varietyName: String
    var originPrefecture: String?
    var tastedDate: String
    var sweetness: Int
    var sourness: Int
    var aroma: Int
    var texture: Int
    var appearance: Int
    var overall: Int
    var purchasePlace: String?
    var priceJPY: Int?
    var comment: String?
    var deletedAt: String?
    var varietyDeletedAt: String?
    var createdAt: String?
    var updatedAt: String?
    var imageBucket: String?
    var imagePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case varietyID = "variety_id"
        case varietyName = "variety_name"
        case originPrefecture = "origin_prefecture"
        case tastedDate = "tasted_date"
        case sweetness
        case sourness
        case aroma
        case texture
        case appearance
        case overall
        case purchasePlace = "purchase_place"
        case priceJPY = "price_jpy"
        case comment
        case deletedAt = "deleted_at"
        case varietyDeletedAt = "variety_deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case imageBucket = "image_bucket"
        case imagePath = "image_path"
    }

    var review: Review {
        Review(
            id: id,
            varietyID: varietyID,
            tastedDate: tastedDate,
            sweetness: sweetness,
            sourness: sourness,
            aroma: aroma,
            texture: texture,
            appearance: appearance,
            overall: overall,
            purchasePlace: purchasePlace,
            priceJPY: priceJPY,
            comment: comment,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    var imageSource: VarietyThumbnailSource? {
        guard let imageBucket, let imagePath else { return nil }
        return VarietyThumbnailSource(bucket: imageBucket, path: imagePath)
    }
}

struct VarietyScoreSummary: Identifiable, Codable, Hashable {
    var varietyID: String
    var varietyName: String
    var reviewCount: Int
    var averageOverall: Double
    var latestReviewDate: String?

    var id: String { varietyID }

    enum CodingKeys: String, CodingKey {
        case varietyID = "variety_id"
        case varietyName = "variety_name"
        case reviewCount = "review_count"
        case averageOverall = "average_overall"
        case latestReviewDate = "latest_review_date"
    }
}

struct TraitScoreSummary: Identifiable, Codable, Hashable {
    var varietyID: String
    var varietyName: String
    var reviewCount: Int
    var averageScore: Double

    var id: String { "\(varietyID)-\(averageScore)" }

    enum CodingKeys: String, CodingKey {
        case varietyID = "variety_id"
        case varietyName = "variety_name"
        case reviewCount = "review_count"
        case averageScore = "average_score"
    }
}

struct TraitLeaderGroup: Codable, Equatable, Hashable {
    var sweetness: [TraitScoreSummary]
    var sourness: [TraitScoreSummary]
    var aroma: [TraitScoreSummary]
    var texture: [TraitScoreSummary]
    var appearance: [TraitScoreSummary]

    static let empty = TraitLeaderGroup(sweetness: [], sourness: [], aroma: [], texture: [], appearance: [])

    enum CodingKeys: String, CodingKey {
        case sweetness
        case sourness
        case aroma
        case texture
        case appearance
    }

    init(sweetness: [TraitScoreSummary], sourness: [TraitScoreSummary], aroma: [TraitScoreSummary], texture: [TraitScoreSummary], appearance: [TraitScoreSummary]) {
        self.sweetness = sweetness
        self.sourness = sourness
        self.aroma = aroma
        self.texture = texture
        self.appearance = appearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sweetness = try container.decodeIfPresent([TraitScoreSummary].self, forKey: .sweetness) ?? []
        sourness = try container.decodeIfPresent([TraitScoreSummary].self, forKey: .sourness) ?? []
        aroma = try container.decodeIfPresent([TraitScoreSummary].self, forKey: .aroma) ?? []
        texture = try container.decodeIfPresent([TraitScoreSummary].self, forKey: .texture) ?? []
        appearance = try container.decodeIfPresent([TraitScoreSummary].self, forKey: .appearance) ?? []
    }
}

struct PrefectureAnalysisSummary: Identifiable, Codable, Hashable {
    var prefecture: String
    var reviewCount: Int
    var varietyCount: Int
    var averageOverall: Double

    var id: String { prefecture }

    enum CodingKeys: String, CodingKey {
        case prefecture
        case reviewCount = "review_count"
        case varietyCount = "variety_count"
        case averageOverall = "average_overall"
    }
}

struct MonthlyReviewSummary: Identifiable, Codable, Hashable {
    var month: String
    var reviewCount: Int
    var averageOverall: Double

    var id: String { month }

    enum CodingKeys: String, CodingKey {
        case month
        case reviewCount = "review_count"
        case averageOverall = "average_overall"
    }
}

struct CostPerformanceSummary: Identifiable, Codable, Hashable {
    var varietyID: String
    var varietyName: String
    var reviewCount: Int
    var averageOverall: Double
    var averagePriceJPY: Double
    var scorePer1000Yen: Double

    var id: String { varietyID }

    enum CodingKeys: String, CodingKey {
        case varietyID = "variety_id"
        case varietyName = "variety_name"
        case reviewCount = "review_count"
        case averageOverall = "average_overall"
        case averagePriceJPY = "average_price_jpy"
        case scorePer1000Yen = "score_per_1000_yen"
    }
}

struct AnalysisSnapshot: Codable, Equatable {
    var generatedAt: String?
    var varietyCount: Int
    var reviewCount: Int
    var discoveredCount: Int
    var averageOverall: Double
    var topOverall: [VarietyScoreSummary]
    var traitLeaders: TraitLeaderGroup
    var prefectures: [PrefectureAnalysisSummary]
    var monthly: [MonthlyReviewSummary]
    var costPerformance: [CostPerformanceSummary]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case varietyCount = "variety_count"
        case reviewCount = "review_count"
        case discoveredCount = "discovered_count"
        case averageOverall = "average_overall"
        case topOverall = "top_overall"
        case traitLeaders = "trait_leaders"
        case prefectures
        case monthly
        case costPerformance = "cost_performance"
    }

    static let empty = AnalysisSnapshot(
        generatedAt: nil,
        varietyCount: 0,
        reviewCount: 0,
        discoveredCount: 0,
        averageOverall: 0,
        topOverall: [],
        traitLeaders: .empty,
        prefectures: [],
        monthly: [],
        costPerformance: []
    )

    static func make(varieties: [Variety], reviews: [Review]) -> AnalysisSnapshot {
        let activeVarieties = varieties.filter { $0.deletedAt == nil }
        let varietiesByID = Dictionary(uniqueKeysWithValues: activeVarieties.map { ($0.id, $0) })
        let activeReviews = reviews.filter { $0.deletedAt == nil && varietiesByID[$0.varietyID] != nil }
        let grouped = Dictionary(grouping: activeReviews, by: \.varietyID)
        let topOverall = grouped.compactMap { varietyID, rows -> VarietyScoreSummary? in
            guard let variety = varietiesByID[varietyID], !rows.isEmpty else { return nil }
            return VarietyScoreSummary(
                varietyID: varietyID,
                varietyName: variety.name,
                reviewCount: rows.count,
                averageOverall: rows.average(\.overall),
                latestReviewDate: rows.map(\.tastedDate).max()
            )
        }
        .sorted {
            if $0.averageOverall != $1.averageOverall {
                return $0.averageOverall > $1.averageOverall
            }
            if $0.reviewCount != $1.reviewCount {
                return $0.reviewCount > $1.reviewCount
            }
            return ($0.latestReviewDate ?? "") > ($1.latestReviewDate ?? "")
        }

        let traitLeaders = TraitLeaderGroup(
            sweetness: Self.traitRows(grouped: grouped, varietiesByID: varietiesByID, keyPath: \.sweetness),
            sourness: Self.traitRows(grouped: grouped, varietiesByID: varietiesByID, keyPath: \.sourness),
            aroma: Self.traitRows(grouped: grouped, varietiesByID: varietiesByID, keyPath: \.aroma),
            texture: Self.traitRows(grouped: grouped, varietiesByID: varietiesByID, keyPath: \.texture),
            appearance: Self.traitRows(grouped: grouped, varietiesByID: varietiesByID, keyPath: \.appearance)
        )

        let prefectures = Dictionary(grouping: activeReviews) { review in
            varietiesByID[review.varietyID]?.originPrefecture ?? "未設定"
        }
        .map { prefecture, rows in
            PrefectureAnalysisSummary(
                prefecture: prefecture,
                reviewCount: rows.count,
                varietyCount: Set(rows.map(\.varietyID)).count,
                averageOverall: rows.average(\.overall)
            )
        }
        .sorted {
            if $0.reviewCount != $1.reviewCount {
                return $0.reviewCount > $1.reviewCount
            }
            return $0.averageOverall > $1.averageOverall
        }

        let monthly = Dictionary(grouping: activeReviews) { String($0.tastedDate.prefix(7)) }
            .map { month, rows in
                MonthlyReviewSummary(month: month, reviewCount: rows.count, averageOverall: rows.average(\.overall))
            }
            .sorted { $0.month > $1.month }

        let costPerformance = grouped.compactMap { varietyID, rows -> CostPerformanceSummary? in
            let pricedRows = rows.filter { ($0.priceJPY ?? 0) > 0 }
            guard let variety = varietiesByID[varietyID], !pricedRows.isEmpty else { return nil }
            let averagePrice = Double(pricedRows.compactMap(\.priceJPY).reduce(0, +)) / Double(pricedRows.count)
            guard averagePrice > 0 else { return nil }
            let averageOverall = pricedRows.average(\.overall)
            return CostPerformanceSummary(
                varietyID: varietyID,
                varietyName: variety.name,
                reviewCount: pricedRows.count,
                averageOverall: averageOverall,
                averagePriceJPY: averagePrice,
                scorePer1000Yen: averageOverall * 1000 / averagePrice
            )
        }
        .sorted { $0.scorePer1000Yen > $1.scorePer1000Yen }

        return AnalysisSnapshot(
            generatedAt: nil,
            varietyCount: activeVarieties.count,
            reviewCount: activeReviews.count,
            discoveredCount: Set(activeReviews.map(\.varietyID)).count,
            averageOverall: activeReviews.average(\.overall),
            topOverall: Array(topOverall.prefix(20)),
            traitLeaders: traitLeaders,
            prefectures: Array(prefectures.prefix(47)),
            monthly: Array(monthly.prefix(24)),
            costPerformance: Array(costPerformance.prefix(20))
        )
    }

    private static func traitRows(
        grouped: [String: [Review]],
        varietiesByID: [String: Variety],
        keyPath: KeyPath<Review, Int>
    ) -> [TraitScoreSummary] {
        grouped.compactMap { varietyID, rows -> TraitScoreSummary? in
            guard let variety = varietiesByID[varietyID], !rows.isEmpty else { return nil }
            return TraitScoreSummary(
                varietyID: varietyID,
                varietyName: variety.name,
                reviewCount: rows.count,
                averageScore: rows.average(keyPath)
            )
        }
        .sorted {
            if $0.averageScore != $1.averageScore {
                return $0.averageScore > $1.averageScore
            }
            return $0.reviewCount > $1.reviewCount
        }
        .prefix(10)
        .map { $0 }
    }
}

private extension Array where Element == Review {
    func average(_ keyPath: KeyPath<Review, Int>) -> Double {
        guard !isEmpty else { return 0 }
        return Double(map { $0[keyPath: keyPath] }.reduce(0, +)) / Double(count)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let string = try decodeIfPresent(String.self, forKey: key) {
            return Double(string)
        }
        return nil
    }
}
