import XCTest
@testable import IchigoDB

@MainActor
final class DataSnapshotTests: XCTestCase {
    func testSnapshotBuildsIndexesAndStatsOnce() {
        let snapshot = LibrarySnapshot.make(
            varieties: [
                Variety(id: "a", name: "A", tags: ["香り"]),
                Variety(id: "b", name: "B")
            ],
            reviews: [
                Review(id: "r1", varietyID: "a", tastedDate: "2026-04-01", sweetness: 5, sourness: 2, aroma: 4, texture: 3, appearance: 5, overall: 8),
                Review(id: "r2", varietyID: "a", tastedDate: "2026-04-20", sweetness: 4, sourness: 3, aroma: 5, texture: 4, appearance: 4, overall: 9)
            ],
            parentLinks: [
                VarietyParentLink(id: "p1", childVarietyID: "a", parentVarietyID: "b", parentOrder: 1)
            ],
            varietyImages: [
                VarietyImage(id: "vi", varietyID: "a", storagePath: "varieties/a/main.jpg", fileName: "main.jpg", mimeType: "image/jpeg", fileSizeBytes: 10, width: nil, height: nil, isPrimary: true, createdAt: "2026-04-01")
            ],
            reviewImages: [
                ReviewImage(id: "ri", reviewID: "r2", storagePath: "reviews/r2/latest.jpg", fileName: "latest.jpg", mimeType: "image/jpeg", fileSizeBytes: 10, width: nil, height: nil, createdAt: "2026-04-20")
            ]
        )

        XCTAssertEqual(snapshot.discoveredIDs, ["a"])
        XCTAssertEqual(snapshot.reviewStatsByVarietyID["a"]?.reviewCount, 2)
        XCTAssertEqual(snapshot.reviewStatsByVarietyID["a"]?.latestReviewID, "r2")
        XCTAssertEqual(snapshot.thumbnailSourceByVarietyID["a"], VarietyThumbnailSource(bucket: "review-images", path: "reviews/r2/latest.jpg"))
        XCTAssertEqual(snapshot.parentsByVarietyID["a"], ["b"])
        XCTAssertEqual(snapshot.childrenByVarietyID["b"], ["a"])
        XCTAssertEqual(snapshot.availableTags, ["香り"])
    }

    func testAnalysisSnapshotRanksAndAggregates() {
        let varieties = [
            Variety(id: "a", name: "A", originPrefecture: "福岡県"),
            Variety(id: "b", name: "B", originPrefecture: "栃木県")
        ]
        let reviews = [
            Review(id: "r1", varietyID: "a", tastedDate: "2026-04-01", sweetness: 5, sourness: 2, aroma: 4, texture: 4, appearance: 5, overall: 9, priceJPY: 900),
            Review(id: "r2", varietyID: "b", tastedDate: "2026-04-02", sweetness: 3, sourness: 4, aroma: 3, texture: 3, appearance: 3, overall: 6, priceJPY: 300)
        ]

        let snapshot = AnalysisSnapshot.make(varieties: varieties, reviews: reviews)

        XCTAssertEqual(snapshot.reviewCount, 2)
        XCTAssertEqual(snapshot.discoveredCount, 2)
        XCTAssertEqual(snapshot.topOverall.first?.varietyID, "a")
        XCTAssertEqual(snapshot.prefectures.map(\.prefecture).sorted(), ["栃木県", "福岡県"])
        XCTAssertEqual(snapshot.monthly.first?.month, "2026-04")
        XCTAssertEqual(snapshot.costPerformance.first?.varietyID, "b")
    }

    func testDuplicateCandidatesExplainMatchKind() {
        let viewModel = makeViewModel()
        viewModel.varieties = [
            Variety(id: "a", registrationNumber: "第12345号", name: "紅ほっぺ", aliasNames: ["べにほっぺ"]),
            Variety(id: "b", name: "イチゴさん")
        ]

        XCTAssertEqual(viewModel.duplicateCandidates(for: "べにほっぺ").first?.kind, .exact)
        XCTAssertEqual(viewModel.duplicateCandidates(for: "12345").first?.kind, .registration)
        XCTAssertEqual(viewModel.duplicateCandidates(for: "いちご").first?.variety.id, "b")
    }

    private func makeViewModel() -> VarietyLibraryViewModel {
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        return VarietyLibraryViewModel(repository: IchigoRepository(client: SupabaseClient(config: config)))
    }
}
