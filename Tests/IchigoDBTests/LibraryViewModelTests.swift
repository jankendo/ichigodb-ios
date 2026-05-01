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

    private func makeViewModel() -> VarietyLibraryViewModel {
        let config = SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon")
        return VarietyLibraryViewModel(repository: IchigoRepository(client: SupabaseClient(config: config)))
    }
}
