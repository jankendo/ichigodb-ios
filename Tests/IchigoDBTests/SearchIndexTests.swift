import XCTest
@testable import IchigoDB

final class SearchIndexTests: XCTestCase {
    func testMatchesKatakanaWithHiraganaQuery() {
        let variety = Variety(id: "1", name: "イチゴさん", aliasNames: ["苺さん"])

        XCTAssertTrue(variety.matchesSearch("いちご"))
        XCTAssertTrue(variety.matchesSearch("苺"))
    }

    func testMatchesRegistrationNumberAndPartialAlias() {
        let variety = Variety(id: "1", registrationNumber: "第12345号", name: "紅ほっぺ", aliasNames: ["べにほっぺ"])

        XCTAssertTrue(variety.matchesSearch("12345"))
        XCTAssertTrue(variety.matchesSearch("ほっぺ"))
        XCTAssertTrue(variety.isExactMatch(for: "べにほっぺ"))
    }

    func testReviewDraftCopiesEditableFields() {
        let review = Review(
            id: "r1",
            varietyID: "v1",
            tastedDate: "2026-05-01",
            sweetness: 5,
            sourness: 2,
            aroma: 4,
            texture: 3,
            appearance: 5,
            overall: 8,
            purchasePlace: "直売所",
            priceJPY: 780,
            comment: "香りが強い"
        )

        let draft = ReviewDraft(review: review)

        XCTAssertEqual(draft.id, "r1")
        XCTAssertEqual(draft.varietyID, "v1")
        XCTAssertEqual(Validation.isoDate(draft.tastedDate), "2026-05-01")
        XCTAssertEqual(draft.purchasePlace, "直売所")
        XCTAssertEqual(draft.priceJPY, 780)
        XCTAssertEqual(draft.comment, "香りが強い")
    }
}
