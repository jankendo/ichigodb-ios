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
}
