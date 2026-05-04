import XCTest
@testable import IchigoDB

final class VarietySelectionSearchTests: XCTestCase {
    func testEmptyQueryLimitsRowsButKeepsSelectedItemsVisible() {
        let varieties = (0..<120).map { index in
            Variety(id: "v\(index)", name: String(format: "品種%03d", index))
        }
        let entries = VarietySearchIndexEntry.makeSorted(from: varieties)

        let result = VarietySelectionSearch.result(
            entries: entries,
            query: "",
            selectedIDs: ["v119"],
            emptyLimit: 20,
            searchLimit: 50
        )

        XCTAssertEqual(result.rows.count, 20)
        XCTAssertEqual(result.rows.first?.id, "v119")
        XCTAssertEqual(result.hiddenCount, 100)
    }

    func testSearchMatchesHiraganaAgainstKatakanaAndLimitsResults() {
        let varieties = [
            Variety(id: "v1", name: "イチゴさん"),
            Variety(id: "v2", name: "紅ほっぺ"),
            Variety(id: "v3", name: "あまおう")
        ]
        let entries = VarietySearchIndexEntry.makeSorted(from: varieties)

        let result = VarietySelectionSearch.result(
            entries: entries,
            query: "いちご",
            emptyLimit: 20,
            searchLimit: 1
        )

        XCTAssertEqual(result.rows.map(\.id), ["v1"])
        XCTAssertEqual(result.hiddenCount, 0)
    }
}
