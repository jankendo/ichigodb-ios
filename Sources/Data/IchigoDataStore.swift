import Combine
import Foundation

@MainActor
final class IchigoDataStore: ObservableObject {
    @Published private(set) var varieties: [Variety]
    @Published private(set) var reviews: [Review]
    @Published private(set) var parentLinks: [VarietyParentLink] = []
    @Published private(set) var varietyImages: [VarietyImage] = []
    @Published private(set) var reviewImages: [ReviewImage] = []
    @Published private(set) var librarySnapshot: LibrarySnapshot = .empty
    @Published private(set) var analysisSnapshot: AnalysisSnapshot = .empty
    @Published private(set) var reviewAnalysisCards: [ReviewAnalysisCard] = []
    @Published private(set) var networkState: NetworkState = .online
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var error: AppError?

    private let repository: IchigoRepository
    private var refreshTask: Task<Void, Never>?

    init(repository: IchigoRepository) {
        self.repository = repository
        self.varieties = repository.cachedVarieties()
        self.reviews = repository.cachedReviews()
        rebuildSnapshots()
    }

    var varietiesByID: [String: Variety] {
        Dictionary(uniqueKeysWithValues: varieties.map { ($0.id, $0) })
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

    func refresh() async {
        refreshTask?.cancel()
        let task = Task { [weak self] in
            await self?.performRefresh()
        }
        refreshTask = task
        await task.value
    }

    func refreshChangedRows(since _: Date?) async {
        await refresh()
    }

    func replaceVarieties(_ rows: [Variety]) {
        varieties = rows
        rebuildSnapshots()
    }

    func replaceReviews(_ rows: [Review]) {
        reviews = rows
        rebuildSnapshots()
    }

    func replaceParentLinks(_ rows: [VarietyParentLink]) {
        parentLinks = rows
        rebuildSnapshots()
    }

    func replaceVarietyImages(_ rows: [VarietyImage]) {
        varietyImages = rows
        rebuildSnapshots()
    }

    func replaceReviewImages(_ rows: [ReviewImage]) {
        reviewImages = rows
        rebuildSnapshots()
    }

    func applyLocalMutation(variety: Variety) {
        upsert(&varieties, row: variety)
        rebuildSnapshots()
    }

    func applyLocalMutation(review: Review) {
        upsert(&reviews, row: review)
        rebuildSnapshots()
    }

    func applyLocalMutation(varietyImage: VarietyImage) {
        upsert(&varietyImages, row: varietyImage)
        rebuildSnapshots()
    }

    func applyLocalMutation(reviewImage: ReviewImage) {
        upsert(&reviewImages, row: reviewImage)
        rebuildSnapshots()
    }

    func markVarietyDeleted(id: String) {
        guard let index = varieties.firstIndex(where: { $0.id == id }) else { return }
        varieties[index].deletedAt = ISO8601DateFormatter().string(from: Date())
        rebuildSnapshots()
    }

    func markReviewDeleted(id: String) {
        guard let index = reviews.firstIndex(where: { $0.id == id }) else { return }
        reviews[index].deletedAt = ISO8601DateFormatter().string(from: Date())
        rebuildSnapshots()
    }

    func restoreReview(id: String) {
        guard let index = reviews.firstIndex(where: { $0.id == id }) else { return }
        reviews[index].deletedAt = nil
        rebuildSnapshots()
    }

    private func performRefresh() async {
        networkState = .syncing
        error = nil
        do {
            async let varietiesTask = repository.fetchVarieties(includeDeleted: true)
            async let reviewsTask = repository.fetchReviews(includeDeleted: true)
            async let linksTask = repository.fetchParentLinks()
            async let varietyImagesTask = repository.fetchVarietyImages()
            async let reviewImagesTask = repository.fetchReviewImages()
            async let analysisCardsTask = repository.fetchReviewAnalysisCardsFallbackAllowed()

            varieties = try await varietiesTask
            reviews = try await reviewsTask
            parentLinks = try await linksTask
            varietyImages = try await varietyImagesTask
            reviewImages = try await reviewImagesTask
            rebuildSnapshots()

            let remoteAnalysis = await repository.fetchAnalysisSnapshotFallbackAllowed(varieties: varieties, reviews: reviews)
            let remoteAnalysisCards = await analysisCardsTask
            if !remoteAnalysisCards.isEmpty {
                reviewAnalysisCards = remoteAnalysisCards
            }
            analysisSnapshot = remoteAnalysis
            lastRefreshDate = Date()
            networkState = .online
        } catch {
            self.error = AppError.from(error)
            networkState = varieties.isEmpty ? .offline : .degraded
            if reviewAnalysisCards.isEmpty {
                reviewAnalysisCards = fallbackReviewAnalysisCards()
            }
            analysisSnapshot = AnalysisSnapshot.make(varieties: varieties, reviews: reviews)
        }
    }

    private func rebuildSnapshots() {
        librarySnapshot = LibrarySnapshot.make(
            varieties: varieties,
            reviews: reviews,
            parentLinks: parentLinks,
            varietyImages: varietyImages,
            reviewImages: reviewImages
        )
        analysisSnapshot = AnalysisSnapshot.make(varieties: varieties, reviews: reviews)
        reviewAnalysisCards = fallbackReviewAnalysisCards()
    }

    private func fallbackReviewAnalysisCards() -> [ReviewAnalysisCard] {
        let varietyNames = Dictionary(uniqueKeysWithValues: varieties.map { ($0.id, $0) })
        let imagesByReviewID = Dictionary(grouping: reviewImages, by: \.reviewID)
            .mapValues { rows in rows.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") } }
        return reviews.map { review in
            let variety = varietyNames[review.varietyID]
            let image = imagesByReviewID[review.id]?.first
            return ReviewAnalysisCard(
                id: review.id,
                varietyID: review.varietyID,
                varietyName: variety?.name ?? "未選択",
                originPrefecture: variety?.originPrefecture,
                tastedDate: review.tastedDate,
                sweetness: review.sweetness,
                sourness: review.sourness,
                aroma: review.aroma,
                texture: review.texture,
                appearance: review.appearance,
                overall: review.overall,
                purchasePlace: review.purchasePlace,
                priceJPY: review.priceJPY,
                comment: review.comment,
                deletedAt: review.deletedAt,
                varietyDeletedAt: variety?.deletedAt,
                createdAt: review.createdAt,
                updatedAt: review.updatedAt,
                imageBucket: image == nil ? nil : "review-images",
                imagePath: image?.storagePath
            )
        }
        .sorted { $0.tastedDate > $1.tastedDate }
    }

    private func upsert<Row: Identifiable>(_ rows: inout [Row], row: Row) where Row.ID == String {
        if let index = rows.firstIndex(where: { $0.id == row.id }) {
            rows[index] = row
        } else {
            rows.append(row)
        }
    }
}
