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

struct VarietyThumbnailSource: Hashable {
    var bucket: String
    var path: String

    var cacheKey: String {
        "\(bucket)/\(path)"
    }
}

@MainActor
final class VarietyLibraryViewModel: ObservableObject {
    @Published var varieties: [Variety] = []
    @Published var reviews: [Review] = []
    @Published var parentLinks: [VarietyParentLink] = []
    @Published var varietyImages: [VarietyImage] = []
    @Published var reviewImages: [ReviewImage] = []
    @Published var signedImageURLs: [String: URL] = [:]
    @Published var loadedImages: [String: UIImage] = [:]
    @Published var searchText = ""
    @Published var lens: LibraryLens = .all
    @Published var sortOption: VarietySortOption = .name
    @Published var discoveryFilter: DiscoveryFilter = .all
    @Published var prefectureFilter = ""
    @Published var selectedTag = ""
    @Published var selectedVarietyID: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: IchigoRepository
    private let imageCache = ImageCacheStore()
    private let loadedImageLimit = 160
    private var loadedImageOrder: [String] = []

    init(repository: IchigoRepository) {
        self.repository = repository
        self.varieties = repository.cachedVarieties()
        self.reviews = repository.cachedReviews()
    }

    var discoveredIDs: Set<String> {
        Set(reviews.filter { $0.deletedAt == nil }.map(\.varietyID))
    }

    var activeVarieties: [Variety] {
        varieties.filter { $0.deletedAt == nil }
    }

    var deletedVarieties: [Variety] {
        varieties.filter { $0.deletedAt != nil }
    }

    var activeReviews: [Review] {
        reviews.filter { $0.deletedAt == nil }
    }

    var deletedReviews: [Review] {
        reviews.filter { $0.deletedAt != nil }
    }

    var progressText: String {
        let total = max(activeVarieties.count, 1)
        let count = discoveredIDs.count
        return "\(count)/\(total)"
    }

    var completionRate: Double {
        guard !activeVarieties.isEmpty else { return 0 }
        return Double(discoveredIDs.count) / Double(activeVarieties.count)
    }

    var availableTags: [String] {
        Array(Set(activeVarieties.flatMap(\.tags))).sorted()
    }

    var filteredVarieties: [Variety] {
        let filtered = activeVarieties.filter { variety in
            if !prefectureFilter.isEmpty && variety.originPrefecture != prefectureFilter {
                return false
            }
            if !selectedTag.isEmpty && !variety.tags.contains(selectedTag) {
                return false
            }
            switch discoveryFilter {
            case .all:
                break
            case .discovered:
                guard discoveredIDs.contains(variety.id) else { return false }
            case .undiscovered:
                guard !discoveredIDs.contains(variety.id) else { return false }
            }
            return variety.matchesSearch(searchText)
        }
        let lensed: [Variety]
        switch lens {
        case .all:
            lensed = filtered
        case .discovered:
            lensed = filtered.filter { discoveredIDs.contains($0.id) }
        case .recent:
            lensed = filtered.filter { latestReview(for: $0.id) != nil }
        case .topRated:
            lensed = filtered.filter { averageOverall(for: $0.id) != nil }
        case .undiscovered:
            lensed = filtered.filter { !discoveredIDs.contains($0.id) }
        }
        return sorted(lensed)
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            async let varietiesTask = repository.fetchVarieties(includeDeleted: true)
            async let reviewsTask = repository.fetchReviews(includeDeleted: true)
            async let linksTask = repository.fetchParentLinks()
            async let varietyImagesTask = repository.fetchVarietyImages()
            async let reviewImagesTask = repository.fetchReviewImages()
            varieties = try await varietiesTask
            reviews = try await reviewsTask
            parentLinks = try await linksTask
            varietyImages = try await varietyImagesTask
            reviewImages = try await reviewImagesTask
            await preloadPrimaryImageURLs()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reviewCount(for varietyID: String) -> Int {
        activeReviews.filter { $0.varietyID == varietyID }.count
    }

    func latestReview(for varietyID: String) -> Review? {
        activeReviews
            .filter { $0.varietyID == varietyID }
            .sorted { $0.tastedDate > $1.tastedDate }
            .first
    }

    func reviews(for varietyID: String) -> [Review] {
        activeReviews
            .filter { $0.varietyID == varietyID }
            .sorted { $0.tastedDate > $1.tastedDate }
    }

    func averageOverall(for varietyID: String) -> Double? {
        let rows = reviews(for: varietyID)
        guard !rows.isEmpty else { return nil }
        return Double(rows.map(\.overall).reduce(0, +)) / Double(rows.count)
    }

    func tasteAverages(for varietyID: String) -> [(String, Double)] {
        let rows = reviews(for: varietyID)
        guard !rows.isEmpty else { return [] }
        let count = Double(rows.count)
        return [
            ("甘味", Double(rows.map(\.sweetness).reduce(0, +)) / count),
            ("酸味", Double(rows.map(\.sourness).reduce(0, +)) / count),
            ("香り", Double(rows.map(\.aroma).reduce(0, +)) / count),
            ("食感", Double(rows.map(\.texture).reduce(0, +)) / count),
            ("見た目", Double(rows.map(\.appearance).reduce(0, +)) / count)
        ]
    }

    func primaryImage(for varietyID: String) -> VarietyImage? {
        let images = images(for: varietyID)
        return images.first(where: \.isPrimary) ?? images.first
    }

    func latestReviewImage(for varietyID: String) -> ReviewImage? {
        for review in reviews(for: varietyID) {
            if let image = reviewImages(for: review.id).max(by: {
                ($0.createdAt ?? "") < ($1.createdAt ?? "")
            }) {
                return image
            }
        }
        return nil
    }

    func thumbnailSource(for varietyID: String) -> VarietyThumbnailSource? {
        if let image = latestReviewImage(for: varietyID) {
            return VarietyThumbnailSource(bucket: "review-images", path: image.storagePath)
        }
        if let image = primaryImage(for: varietyID) {
            return VarietyThumbnailSource(bucket: "variety-images", path: image.storagePath)
        }
        return nil
    }

    func gallerySources(for varietyID: String) -> [VarietyThumbnailSource] {
        let reviewSources = reviews(for: varietyID)
            .flatMap { review in
                reviewImages(for: review.id)
                    .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
                    .map { VarietyThumbnailSource(bucket: "review-images", path: $0.storagePath) }
            }
        let varietySources = images(for: varietyID)
            .map { VarietyThumbnailSource(bucket: "variety-images", path: $0.storagePath) }

        var seen = Set<String>()
        return (reviewSources + varietySources).filter { source in
            if seen.contains(source.cacheKey) {
                return false
            }
            seen.insert(source.cacheKey)
            return true
        }
    }

    func images(for varietyID: String) -> [VarietyImage] {
        varietyImages
            .filter { $0.varietyID == varietyID }
            .sorted {
                if $0.isPrimary != $1.isPrimary {
                    return $0.isPrimary && !$1.isPrimary
                }
                return ($0.createdAt ?? "") < ($1.createdAt ?? "")
            }
    }

    func reviewImages(for reviewID: String) -> [ReviewImage] {
        reviewImages
            .filter { $0.reviewID == reviewID }
            .sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
    }

    func parents(for varietyID: String) -> [Variety] {
        let ids = parentLinks
            .filter { $0.childVarietyID == varietyID }
            .sorted { ($0.parentOrder ?? 0) < ($1.parentOrder ?? 0) }
            .map(\.parentVarietyID)
        return ids.compactMap { id in varieties.first(where: { $0.id == id }) }
    }

    func children(for varietyID: String) -> [Variety] {
        let ids = parentLinks
            .filter { $0.parentVarietyID == varietyID }
            .map(\.childVarietyID)
        let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
        return varieties
            .filter { order[$0.id] != nil && $0.deletedAt == nil }
            .sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }

    func varietyName(_ id: String) -> String {
        varieties.first(where: { $0.id == id })?.name ?? "未選択"
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
        signedImageURLs[cacheKey(bucket: bucket, path: path)]
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
            // Missing image URLs should not block the app.
        }
    }

    func ensureImage(bucket: String, path: String) async {
        let key = cacheKey(bucket: bucket, path: path)
        guard loadedImages[key] == nil else { return }
        if let cached = imageCache.image(bucket: bucket, path: path) {
            rememberLoadedImage(cached, key: key)
            return
        }
        do {
            let data = try await repository.downloadImageData(bucket: bucket, path: path)
            rememberLoadedImage(imageCache.store(data, bucket: bucket, path: path), key: key)
        } catch {
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
        imageCache.remove(bucket: bucket, path: path)
    }

    func deleteVariety(_ id: String) async {
        do {
            try await repository.softDeleteVariety(id: id)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preloadPrimaryImageURLs() async {
        let firstImages = activeVarieties.compactMap { thumbnailSource(for: $0.id) }.prefix(80)
        for image in firstImages {
            await ensureImage(for: image)
        }
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

    private func sorted(_ rows: [Variety]) -> [Variety] {
        switch lens {
        case .all:
            switch sortOption {
            case .name:
                return rows.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            case .latestReview:
                return rows.sorted { (latestReview(for: $0.id)?.tastedDate ?? "") > (latestReview(for: $1.id)?.tastedDate ?? "") }
            case .averageScore:
                return rows.sorted { (averageOverall(for: $0.id) ?? -1) > (averageOverall(for: $1.id) ?? -1) }
            case .registeredYear:
                return rows.sorted { ($0.registeredYear ?? 0) > ($1.registeredYear ?? 0) }
            }
        case .discovered:
            return rows.sorted {
                let leftDate = latestReview(for: $0.id)?.tastedDate ?? ""
                let rightDate = latestReview(for: $1.id)?.tastedDate ?? ""
                if leftDate != rightDate {
                    return leftDate > rightDate
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .recent:
            return rows.sorted { (latestReview(for: $0.id)?.tastedDate ?? "") > (latestReview(for: $1.id)?.tastedDate ?? "") }
        case .topRated:
            return rows.sorted { (averageOverall(for: $0.id) ?? 0) > (averageOverall(for: $1.id) ?? 0) }
        case .undiscovered:
            return rows.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
