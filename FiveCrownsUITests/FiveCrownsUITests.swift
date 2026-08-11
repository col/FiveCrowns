import XCTest

/// One smoke test: the app launches and presents a usable scorecard.
/// Deeper behaviour is covered by the unit suite, which runs in a
/// fraction of the time.
@MainActor
final class FiveCrownsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesToAUsableScorecard() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.buttons["Add Player"].waitForExistence(timeout: 10),
            "Expected the Add Player button on a scorecard with no players"
        )
    }
}
