import XCTest

final class TinySignerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsWelcomeScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-empty"]
        app.launchEnvironment = [
            "TINYSIGNER_UI_TEST": "1",
            "TINYSIGNER_UI_TEST_EMPTY": "1"
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["welcomeTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["welcomeOpenPDFButton"].exists)
    }

    @MainActor
    func testLaunchWithDemoFixtureShowsEditor() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest"]
        app.launchEnvironment = [
            "TINYSIGNER_UI_TEST": "1"
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["editorWorkspace"].waitForExistence(timeout: 5))
    }
}
