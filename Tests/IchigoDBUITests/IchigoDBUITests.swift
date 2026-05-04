import XCTest

final class IchigoDBUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainTabsRemainSwitchable() throws {
        let app = XCUIApplication()
        app.launch()

        for title in ["ホーム", "図鑑", "登録", "評価", "分析"] {
            let button = app.tabBars.buttons[title]
            XCTAssertTrue(button.waitForExistence(timeout: 8), "\(title) tab should exist")
            button.tap()
            XCTAssertTrue(button.isSelected, "\(title) tab should be selectable")
        }
    }
}
