import XCTest
@testable import IchigoDB

final class VarietyShareBuilderTests: XCTestCase {
    func testShareTextIncludesVarietyReviewSummaryAndRecentReviews() {
        let variety = Variety(
            id: "v1",
            name: "紅ほっぺ",
            description: "香りが強く、食べ比べでも印象に残る品種。",
            originPrefecture: "静岡県"
        )
        let parent = Variety(id: "p1", name: "章姫")
        let review = Review(
            id: "r1",
            varietyID: "v1",
            tastedDate: "2026-05-03",
            sweetness: 5,
            sourness: 2,
            aroma: 4,
            texture: 4,
            appearance: 5,
            overall: 8,
            purchasePlace: "直売所",
            priceJPY: 780,
            comment: "香りが良く、甘味が伸びる。"
        )

        let text = VarietyShareBuilder.makeText(
            variety: variety,
            reviews: [review],
            reviewCount: 1,
            averageOverall: 8,
            parents: [parent],
            children: [],
            isDiscovered: true
        )

        XCTAssertTrue(text.contains("IchigoDB 品種レポート"))
        XCTAssertTrue(text.contains("品種: 紅ほっぺ"))
        XCTAssertTrue(text.contains("発見状態: 発見済み"))
        XCTAssertTrue(text.contains("評価: 1件 / 平均 8.0/10"))
        XCTAssertTrue(text.contains("親品種: 章姫"))
        XCTAssertTrue(text.contains("2026-05-03 総合 8/10"))
        XCTAssertTrue(text.contains("購入場所: 直売所"))
    }
}
