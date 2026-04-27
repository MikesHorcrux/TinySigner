import AppKit
import CoreGraphics
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

    @MainActor
    func testLaunchWithSmartFixtureCanAcceptSuggestion() throws {
        let fixtureURL = try Self.makeSmartFixturePDF()
        let app = XCUIApplication()
        app.launchArguments = ["--uitest"]
        app.launchEnvironment = [
            "TINYSIGNER_UI_TEST": "1",
            "TINYSIGNER_OPEN_PDF": fixtureURL.path
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["editorWorkspace"].waitForExistence(timeout: 5))
        let acceptButton = app.descendants(matching: .any)["acceptSmartSuggestionsButton"]
        XCTAssertTrue(acceptButton.waitForExistence(timeout: 5))
        acceptButton.click()
    }

    @MainActor
    func testSettingsWindowOpens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-empty"]
        app.launchEnvironment = [
            "TINYSIGNER_UI_TEST": "1",
            "TINYSIGNER_UI_TEST_EMPTY": "1"
        ]
        app.launch()

        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["settingsTitle"].waitForExistence(timeout: 5))
    }

    private static func makeSmartFixturePDF() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TinySignerUISmartFixture-\(UUID().uuidString).pdf")
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "TinySignerUITests", code: 1)
        }

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        drawText("TinySigner UI Smart Fixture", in: CGRect(x: 72, y: 700, width: 420, height: 36))
        drawText("Signature", in: CGRect(x: 72, y: 218, width: 140, height: 24))
        drawLine(from: CGPoint(x: 72, y: 210), to: CGPoint(x: 292, y: 210), context: context)
        drawText("Date", in: CGRect(x: 340, y: 218, width: 90, height: 24))
        drawLine(from: CGPoint(x: 340, y: 210), to: CGPoint(x: 480, y: 210), context: context)

        NSGraphicsContext.current = previous
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        return url
    }

    private static func drawText(_ text: String, in rect: CGRect) {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.black
            ]
        )
        .draw(in: rect)
    }

    private static func drawLine(from start: CGPoint, to end: CGPoint, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.2)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }
}
