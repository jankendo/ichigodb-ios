import XCTest
@testable import IchigoDB

final class ValidationTests: XCTestCase {
    func testVarietyNameIsTrimmed() throws {
        XCTAssertEqual(try Validation.requireName("  あまおう  "), "あまおう")
    }

    func testInvalidBrixRangeThrows() {
        XCTAssertThrowsError(try Validation.validateBrix(min: 12.1, max: 11.0))
    }

    func testReviewOverallIsFastAverageScore() {
        var draft = ReviewDraft()
        draft.sweetness = 5
        draft.sourness = 4
        draft.aroma = 4
        draft.texture = 5
        draft.appearance = 4
        XCTAssertEqual(draft.overall, 9)
    }

    func testVarietyDraftParsesAliasNames() {
        var draft = VarietyDraft()
        draft.aliasNamesText = "あまおう, 甘王、 Amaou"

        XCTAssertEqual(draft.aliasNames, ["あまおう", "甘王", "Amaou"])
    }

    func testReviewDraftCodableRoundTrip() throws {
        var draft = ReviewDraft()
        draft.varietyID = "v1"
        draft.comment = "よい香り"

        let data = try JSONEncoder().encode(draft)
        let restored = try JSONDecoder().decode(ReviewDraft.self, from: data)

        XCTAssertEqual(restored.varietyID, "v1")
        XCTAssertEqual(restored.comment, "よい香り")
    }
}
