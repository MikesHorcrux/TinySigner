import XCTest

final class TinySignerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsWelcomeScreen() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["TinySigner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open PDF"].exists)
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
