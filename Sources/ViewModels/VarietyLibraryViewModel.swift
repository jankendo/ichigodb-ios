import Foundation
import SwiftUI
import UIKit

enum DiscoveryFilter: String, CaseIterable, Identifiable {
    case all = "すべて"
    case discovered = "発見済み"
    case undiscovered = "未発見"

    var id: String { rawValue }
}

enum LibraryLens: String, CaseIterable, Identifiable {
    case all = "全品種"
    case discovered = "発見済み"
    case recent = "最近評価"
    case topRated = "高評価"
    case undiscovered = "未発見"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .discovered:
            return "checkmark.seal"
        case .recent:
            return "clock.arrow.circlepath"
        case .topRated:
            return "star.fill"
        case .undiscovered:
            return "questionmark.circle"
        }
    }
}

enum VarietySortOption: String, CaseIterable, Identifiable {
    case name = "名前"
    case latestReview = "最新評価"
    case averageScore = "平均点"
    case registeredYear = "登録年"

    var id: String { rawValue }
}

struct VarietyThumbnailSource: Hashable, Codable {
    var bucket: String
    var path: String

    var cacheKey: String {
        "\(bucket)/\(path)"
    }
}

struct VarietyMatchCandidate: Identifiable, Equatable {
    enum MatchKind: String {
        case exact = "完全一致"
        case kana = "かな一致"
        case alias = "別名一致"
        case registration = "登録番号"
        case partial = "部分一致"
    }

    var variety: Variety
    var kind: MatchKind
    var score: Int

    var id: String { variety.id }
}

@MainActor
final class VarietyLibraryViewModel: ObservableObject {
    @Published var signedImageURLs: [String: URL] = [:]
    @Published var loadedImages: [String: UIImage] = [:]
    @Published var searchText = "" { didSet { scheduleFilteredRefresh() } }
    @Published var lens: LibraryLens = .all { didSet { rebuildFilteredNow() } }
    @Published var sortOption: VarietySortOption = .name { didSet { rebuildFilteredNow() } }
    @Published var discoveryFilter: DiscoveryFilter = .all { didSet { rebuildFilteredNow() } }
    @Published var prefectureFilter = "" { didSet { rebuildFilteredNow() } }
    @Published var selectedTag = "" { didSet { rebuildFilteredNow() } }
    @Published var selectedVarietyID: String?
    @Published private(set) var filteredVarieties: [Variety] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: IchigoRepository
    private let dataStore: IchigoDataStore
    private let imagePipeline = ImagePipeline()
    private let loadedImageLimit = 160
    private var loadedImageOrder: [String] = []
    private var filterTask: Task<Void, Never>?

    init(repository: IchigoRepository, dataStore: IchigoDataStore? = nil) {
        self.repository = repository
        self.dataStore = dataStore ?? IchigoDataStore(repository: repository)
        rebuildFilteredNow()
    }

    var varieties: [Variety] {
        get { dataStore.varieties }
        set {
            dataStore.replaceVarieties(newValue)
            rebuildFilteredNow()
        }
    }

    var reviews: [Review] {
        get { dataStore.reviews }
        set {
            dataStore.replaceReviews(newValue)
            rebuildFilteredNow()
        }
    }

    var parentLinks: [VarietyParentLink] {
        get { dataStore.parentLinks }
        set {
            dataStore.replaceParentLinks(newValue)
            rebuildFilteredNow()
        }
    }

    var varietyImages: [VarietyImage] {
        get { dataStore.varietyImages }
        set {
            dataStore.replaceVarietyImages(newValue)
            rebuildFilteredNow()
        }
    }

    var reviewImages: [ReviewImage] {
        get { dataStore.reviewImages }
        set {
            dataStore.replaceReviewImages(newValue)
            rebuildFilteredNow()
        }
    }

    var analysisSnapshot: AnalysisSnapshot {
        dataStore.analysisSnapshot
    }

    var reviewAnalysisCards: [ReviewAnalysisCard] {
        dataStore.reviewAnalysisCards
    }

    var networkState: NetworkState {
        dataStore.networkState
    }

    var discoveredIDs: Set<String> {
        dataStore.librarySnapshot.discoveredIDs
    }

    var activeVarieties: [Variety] {
        dataStore.activeVarieties
    }

    var deletedVarieties: [Variety] {
        dataStore.deletedVarieties
    }

    var activeReviews: [Review] {
        dataStore.activeReviews
    }

    var deletedReviews: [Review] {
        dataStore.deletedReviews
    }

    var progressText: String {
        let total = max(activeVarieties.count, 1)
        return "\(discoveredIDs.count)/\(total)"
    }

    var completionRate: Double {
        guard !activeVarieties.isEmpty else { return 0 }
        return Double(discoveredIDs.count) / Double(activeVarieties.count)
    }

    var availableTags: [String] {
        dataStore.librarySnapshot.availableTags
    }

    var recentReviewCards: [ReviewAnalysisCard] {
        dataStore.reviewAnalysisCards
            .filter { $0.deletedAt == nil }
            .sorted { $0.tastedDate > $1.tastedDate }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        await dataStore.refresh()
        rebuildFilteredNow()
        if let error = dataStore.error, dataStore.networkState != .online {
            errorMessage = error.localizedDescription
        }
        prefetchVisibleThumbnails()
        isLoading = false
    }

    func applySavedVariety(_ variety: Variety) {
        dataStore.applyLocalMutation(variety: variety)
        rebuildFilteredNow()
    }

    func applySavedReview(_ review: Review) {
        dataStore.applyLocalMutation(review: review)
        rebuildFilteredNow()
        prefetchVisibleThumbnails()
    }

    func reviewCount(for varietyID: String) -> Int {
        dataStore.librarySnapshot.reviewStatsByVarietyID[varietyID]?.reviewCount ?? 0
    }

    func latestReview(for varietyID: String) -> Review? {
        dataStore.librarySnapshot.latestReviewByVarietyID[varietyID]
    }

    func reviews(for varietyID: String) -> [Review] {
        dataStore.librarySnapshot.reviewsByVarietyID[varietyID] ?? []
    }

    func averageOverall(for varietyID: String) -> Double? {
        dataStore.librarySnapshot.reviewStatsByVarietyID[varietyID]?.averageOverall
    }

    func tasteAverages(for varietyID: String) -> [(String, Double)] {
        guard let stats = dataStore.librarySnapshot.reviewStatsByVarietyID[varietyID],
              stats.reviewCount > 0 else {
            return []
        }
        return [
            ("甘味", stats.sweetnessAverage ?? 0),
            ("酸味", stats.sournessAverage ?? 0),
            ("香り", stats.aromaAverage ?? 0),
            ("食感", stats.textureAverage ?? 0),
            ("見た目", stats.appearanceAverage ?? 0)
        ]
    }

    func primaryImage(for varietyID: String) -> VarietyImage? {
        let images = images(for: varietyID)
        return images.first(where: \.isPrimary) ?? images.first
    }

    func latestReviewImage(for varietyID: String) -> ReviewImage? {
        for review in reviews(for: varietyID) {
            if let image = reviewImages(for: review.id).first {
                return image
            }
        }
        return nil
    }

    func thumbnailSource(for varietyID: String) -> VarietyThumbnailSource? {
        dataStore.librarySnapshot.thumbnailSourceByVarietyID[varietyID]
    }

    func gallerySources(for varietyID: String) -> [VarietyThumbnailSource] {
        let reviewSources = reviews(for: varietyID)
            .flatMap { review in
                reviewImages(for: review.id)
                    .map { VarietyThumbnailSource(bucket: "review-images", path: $0.storagePath) }
            }
        let varietySources = images(for: varietyID)
            .map { VarietyThumbnailSource(bucket: "variety-images", path: $0.storagePath) }

        var seen = Set<String>()
        return (reviewSources + varietySources).filter { source in
            guard !seen.contains(source.cacheKey) else { return false }
            seen.insert(source.cacheKey)
            return true
        }
    }

    func images(for varietyID: String) -> [VarietyImage] {
        dataStore.librarySnapshot.varietyImagesByVarietyID[varietyID] ?? []
    }

    func reviewImages(for reviewID: String) -> [ReviewImage] {
        dataStore.librarySnapshot.reviewImagesByReviewID[reviewID] ?? []
    }

    func parents(for varietyID: String) -> [Variety] {
        let ids = dataStore.librarySnapshot.parentsByVarietyID[varietyID] ?? []
        let varietiesByID = dataStore.varietiesByID
        return ids.compactMap { varietiesByID[$0] }
    }

    func children(for varietyID: String) -> [Variety] {
        let ids = dataStore.librarySnapshot.childrenByVarietyID[varietyID] ?? []
        let varietiesByID = dataStore.varietiesByID
        return ids.compactMap { id in
            guard let variety = varietiesByID[id], variety.deletedAt == nil else { return nil }
            return variety
        }
    }

    func varietyName(_ id: String) -> String {
        dataStore.varietiesByID[id]?.name ?? "未選択"
    }

    func imageURL(for image: VarietyImage?) -> URL? {
        guard let image else { return nil }
        return imageURL(bucket: "variety-images", path: image.storagePath)
    }

    func imageURL(for source: VarietyThumbnailSource?) -> URL? {
        guard let source else { return nil }
        return imageURL(bucket: source.bucket, path: source.path)
    }

    func imageURL(bucket: String, path: String) -> URL? {
        signedImageURLs[cacheKey(bucket: bucket, path: path)] ?? repository.publicImageURL(bucket: bucket, path: path)
    }

    func loadedImage(bucket: String, path: String?) -> UIImage? {
        guard let path else { return nil }
        return loadedImages[cacheKey(bucket: bucket, path: path)]
    }

    func loadedImage(for source: VarietyThumbnailSource?) -> UIImage? {
        guard let source else { return nil }
        return loadedImage(bucket: source.bucket, path: source.path)
    }

    func ensureSignedURL(for image: VarietyImage) async {
        await ensureSignedURL(bucket: "variety-images", path: image.storagePath)
    }

    func ensureSignedURL(bucket: String, path: String) async {
        let key = cacheKey(bucket: bucket, path: path)
        guard signedImageURLs[key] == nil else { return }
        do {
            signedImageURLs[key] = try await repository.signedURL(bucket: bucket, path: path)
        } catch {
            // A missing image URL should not block text-first browsing.
        }
    }

    func ensureImage(bucket: String, path: String, targetPixelSize: Int = 640) async {
        let key = cacheKey(bucket: bucket, path: path)
        guard loadedImages[key] == nil else { return }
        if let cached = imagePipeline.cachedImage(bucket: bucket, path: path, targetPixelSize: targetPixelSize) {
            rememberLoadedImage(cached, key: key)
            return
        }
        let request = ImageRequest(bucket: bucket, path: path, targetPixelSize: targetPixelSize, priority: .visible)
        if let image = await imagePipeline.image(for: request, repository: repository) {
            rememberLoadedImage(image, key: key)
        } else {
            await ensureSignedURL(bucket: bucket, path: path)
        }
    }

    func ensureImage(for source: VarietyThumbnailSource?) async {
        guard let source else { return }
        await ensureImage(bucket: source.bucket, path: source.path)
    }

    func clearCachedImage(bucket: String, path: String) {
        let key = cacheKey(bucket: bucket, path: path)
        loadedImages[key] = nil
        loadedImageOrder.removeAll { $0 == key }
        signedImageURLs[key] = nil
        imagePipeline.remove(bucket: bucket, path: path)
    }

    func duplicateCandidates(for query: String, limit: Int = 8) -> [VarietyMatchCandidate] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }
        let compactQuery = cleaned.compactSearchText
        return activeVarieties.compactMap { variety in
            if variety.isExactMatch(for: cleaned) {
                return VarietyMatchCandidate(variety: variety, kind: .exact, score: 100)
            }
            if variety.registrationNumber?.compactSearchText.contains(compactQuery) == true ||
                variety.applicationNumber?.compactSearchText.contains(compactQuery) == true {
                return VarietyMatchCandidate(variety: variety, kind: .registration, score: 90)
            }
            if variety.aliasNames.contains(where: { $0.compactSearchText.contains(compactQuery) }) {
                return VarietyMatchCandidate(variety: variety, kind: .alias, score: 80)
            }
            if variety.name.compactSearchText.contains(compactQuery) {
                return VarietyMatchCandidate(variety: variety, kind: .kana, score: 70)
            }
            if variety.matchesSearch(cleaned) {
                return VarietyMatchCandidate(variety: variety, kind: .partial, score: 50)
            }
            return nil
        }
        .sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.variety.name.localizedStandardCompare($1.variety.name) == .orderedAscending
        }
        .prefix(limit)
        .map { $0 }
    }

    func deleteVariety(_ id: String) async {
        dataStore.markVarietyDeleted(id: id)
        rebuildFilteredNow()
        do {
            try await repository.softDeleteVariety(id: id)
        } catch {
            errorMessage = error.localizedDescription
            await reload()
        }
    }

    private func scheduleFilteredRefresh() {
        filterTask?.cancel()
        filterTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.rebuildFilteredNow()
                self?.prefetchVisibleThumbnails()
            }
        }
    }

    private func rebuildFilteredNow() {
        let cards = dataStore.librarySnapshot.cards.filter { card in
            guard card.deletedAt == nil else { return false }
            if !prefectureFilter.isEmpty && card.originPrefecture != prefectureFilter {
                return false
            }
            if !selectedTag.isEmpty && !card.tags.contains(selectedTag) {
                return false
            }
            switch discoveryFilter {
            case .all:
                break
            case .discovered:
                guard discoveredIDs.contains(card.id) else { return false }
            case .undiscovered:
                guard !discoveredIDs.contains(card.id) else { return false }
            }
            return card.matchesSearch(searchText)
        }

        let lensed: [VarietyLibraryCard]
        switch lens {
        case .all:
            lensed = cards
        case .discovered:
            lensed = cards.filter { discoveredIDs.contains($0.id) }
        case .recent:
            lensed = cards.filter { $0.latestReviewDate != nil }
        case .topRated:
            lensed = cards.filter { $0.averageOverall != nil }
        case .undiscovered:
            lensed = cards.filter { !discoveredIDs.contains($0.id) }
        }

        let sortedCards = sorted(lensed)
        let varietiesByID = dataStore.varietiesByID
        filteredVarieties = sortedCards.compactMap { varietiesByID[$0.id] }
    }

    private func prefetchVisibleThumbnails() {
        let sources = filteredVarieties.compactMap { thumbnailSource(for: $0.id) }
        imagePipeline.prefetch(sources, repository: repository, targetPixelSize: 640)
    }

    private func cacheKey(bucket: String, path: String) -> String {
        "\(bucket)/\(path)"
    }

    private func rememberLoadedImage(_ image: UIImage?, key: String) {
        guard let image else {
            loadedImages[key] = nil
            loadedImageOrder.removeAll { $0 == key }
            return
        }
        loadedImages[key] = image
        loadedImageOrder.removeAll { $0 == key }
        loadedImageOrder.append(key)
        while loadedImageOrder.count > loadedImageLimit, let oldest = loadedImageOrder.first {
            loadedImageOrder.removeFirst()
            loadedImages[oldest] = nil
        }
    }

    private func sorted(_ rows: [VarietyLibraryCard]) -> [VarietyLibraryCard] {
        switch lens {
        case .all:
            switch sortOption {
            case .name:
                return rows.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            case .latestReview:
                return rows.sorted { ($0.latestReviewDate ?? "") > ($1.latestReviewDate ?? "") }
            case .averageScore:
                return rows.sorted { ($0.averageOverall ?? -1) > ($1.averageOverall ?? -1) }
            case .registeredYear:
                let varietiesByID = dataStore.varietiesByID
                return rows.sorted { (varietiesByID[$0.id]?.registeredYear ?? 0) > (varietiesByID[$1.id]?.registeredYear ?? 0) }
            }
        case .discovered:
            return rows.sorted {
                if ($0.latestReviewDate ?? "") != ($1.latestReviewDate ?? "") {
                    return ($0.latestReviewDate ?? "") > ($1.latestReviewDate ?? "")
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .recent:
            return rows.sorted { ($0.latestReviewDate ?? "") > ($1.latestReviewDate ?? "") }
        case .topRated:
            return rows.sorted { ($0.averageOverall ?? 0) > ($1.averageOverall ?? 0) }
        case .undiscovered:
            return rows.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
