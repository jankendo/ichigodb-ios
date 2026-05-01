import XCTest
@testable import IchigoDB

@MainActor
final class LibraryViewModelTests: XCTestCase {
    func testLibraryLensFiltersAndSortsByRecentReviews() {
        let viewModel = makeViewModel()
        viewModel.varieties = [
            Variety(id: "a", name: "A"),
            Variety(id: "b", name: "B"),
            Variety(id: "c", name: "C")
        ]
        viewModel.reviews = [
            Review(id: "r1", varietyID: "a", tastedDate: "2026-04-01", sweetness: 5, sourness: 4, aroma: 4, texture: 4, appearance: 5, overall: 9),
            Review(id: "r2", varietyID: "b", tastedDate: "2026-04-20", sweetness: 3, sourness: 3, aroma: 3, texture: 3, appearance: 3, overall: 6)
        ]
        viewModel.lens = .recent

        XCTAssertEqual(viewModel.filteredVarieties.map(\.id), ["b", "a"])
    }

    func testLibraryLensFiltersUndiscoveredAndTags() {
        let viewModel = makeViewModel()
        viewModel.varieties = [
            Variety(id: "a", name: "A", tags: ["香り"]),
            Variety(id: "b", name: "B", tags: ["大粒"]),
            Variety(id: "c", name: "C", tags: ["香り"])
        ]
        viewModel.reviews = [
            Review(id: "r1", varietyID: "a", tastedDate: "2026-04-01", sweetness: 5, sourness: 4, aroma: 4, texture: 4, appearance: 5, overall: 9)
        ]
        viewModel.lens = .undiscovered
        viewModel.selectedTag = "香り"

        XCTAssertEqual(viewModel.filteredVarieties.map(\.id), ["c"])
    }

    func testLibraryLensFiltersDiscoveredByLatestReview() {
        let viewModel = makeViewModel()
        viewModel.varieties = [
            Variety(id: "a", name: "A"),
            Variety(id: "b", name: "B"),
            Variety(id: "c", name: "C")
        ]
        viewModel.reviews = [
            Review(id: "r1", varietyID: "a", tastedDate: "2026-04-01", sweetness: 5, sourness: 4, aroma: 4, texture: 4, appearance: 5, overall: 9),
            Review(id: "r2", varietyID: "b", tastedDate: "2026-04-20", sweetness: 3, sourness: 3, aroma: 3, texture: 3, appearance: 3, overall: 6)
        ]
        viewModel.lens = .discovered

        XCTAssertEqual(viewModel.filteredVarieties.map(\.id), ["b", "a"])
    }

    func testThumbnailPrefersLatestReviewImageOverVarietyImage() {
        let viewModel = makeViewModel()
        viewModel.varieties = [Variety(id: "a", name: "A")]
        viewModel.reviews = [
            Review(id: "old", varietyID: "a", tastedDate: "2026-04-01", sweetness: 3, sourness: 3, aroma: 3, texture: 3, appearance: 3, overall: 6),
            Review(id: "new", varietyID: "a", tastedDate: "2026-04-20", sweetness: 5, sourness: 4, aroma: 5, texture: 5, appearance: 4, overall: 9)
        ]
        viewModel.varietyImages = [
            VarietyImage(id: "vi", varietyID: "a", storagePath: "varieties/a/main.jpg", fileName: "main.jpg", mimeType: "image/jpeg", fileSizeBytes: 12, width: nil, height: nil, isPrimary: true, createdAt: "2026-04-01")
        ]
        viewModel.reviewImages = [
            ReviewImage(id: "ri1", reviewID: "old", storagePath: "reviews/old/photo.jpg", fileName: "photo.jpg", mimeType: "image/jpeg", fileSizeBytes: 12, width: nil, height: nil, createdAt: "2026-04-01"),
            ReviewImage(id: "ri2", reviewID: "new", storagePath: "reviews/new/photo.jpg", fileName: "photo.jpg", mimeType: "image/jpeg", fileSizeBytes: 12, width: nil, height: nil, createdAt: "2026-04-20")
        ]

        XCTAssertEqual(viewModel.thumbnailSource(for: "a"), VarietyThumbnailSource(bucket: "review-images", path: "reviews/new/photo.jpg"))
    }

    func testBatchReviewQueueCreatesDraftForEachSelectedVariety() {
        let viewModel = makeReviewViewModel()
        viewModel.draft.sweetness = 5
        viewModel.draft.comment = "食べ比べ"

        viewModel.addBatchToQueue(varietyIDs: ["b", "a", "a"], nameResolver: { ["a": "A", "b": "B"][$0] ?? $0 })

        XCTAssertEqual(viewModel.queuedDrafts.count, 2)
        XCTAssertEqual(Set(viewModel.queuedDrafts.map(\.draft.varietyID)), ["a", "b"])
        XCTAssertTrue(viewModel.queuedDrafts.allSatisfy { $0.draft.sweetness == 5 && $0.draft.comment == "食べ比べ" })
    }

    private func makeViewModel() -> VarietyLibraryViewModel {
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        return VarietyLibraryViewModel(repository: IchigoRepository(client: SupabaseClient(config: config)))
    }

    private func makeReviewViewModel() -> ReviewEditorViewModel {
        UserDefaults.standard.removeObject(forKey: "IchigoDB.reviewDraft.v1")
        UserDefaults.standard.removeObject(forKey: "IchigoDB.reviewQueue.v1")
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        return ReviewEditorViewModel(repository: IchigoRepository(client: SupabaseClient(config: config)))
    }
}
