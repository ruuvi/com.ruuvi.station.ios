import XCTest
import Vision

final class WidgetGalleryTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testWidgetsAppearInSystemGalleryAndRenderPreview() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["dashboard.menu"].waitForExistence(timeout: 20))
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        addTeardownBlock {
            self.showHomeScreen(springboard)
            app.activate()
        }
        showHomeScreen(springboard)
        func visibleIcon() -> XCUIElement? {
            springboard.icons.matching(identifier: "Ruuvi Station").allElementsBoundByIndex.first { $0.isHittable }
        }
        for _ in 0..<6 where visibleIcon() == nil { springboard.swipeRight() }
        for _ in 0..<6 where visibleIcon() == nil { springboard.swipeLeft() }
        attach(springboard, name: "Home before widget gallery")
        guard let icon = visibleIcon() else {
            XCTFail("Installed Ruuvi Station icon is not reachable: \(springboard.debugDescription)")
            return
        }
        icon.press(forDuration: 1.2)
        attach(springboard, name: "Widget app context menu")
        let editHome = springboard.buttons["Edit Home Screen"].firstMatch
        XCTAssertTrue(editHome.waitForExistence(timeout: 5), springboard.debugDescription)
        editHome.tap()
        let edit = springboard.buttons["Edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5), springboard.debugDescription)
        edit.tap()
        let addWidgets = springboard.buttons["Add Widget"].firstMatch
        XCTAssertTrue(addWidgets.waitForExistence(timeout: 5), springboard.debugDescription)
        addWidgets.tap()
        let search = springboard.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), springboard.debugDescription)
        search.tap()
        search.typeText("Ruuvi")
        let result = springboard.staticTexts["Ruuvi Station"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), springboard.debugDescription)
        result.tap()
        XCTAssertTrue(
            springboard.staticTexts["Ruuvi Widget"].firstMatch.waitForExistence(timeout: 10),
            springboard.debugDescription)
        let preview = springboard.buttons["Ruuvi Station, Ruuvi Widget"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        // SpringBoard exposes the preview as one button, without its rendered text.
        var text = ""
        for _ in 0..<10 {
            text = try recognizedText(in: preview.screenshot())
            if text.contains("Sauna") && text.contains("78") { break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        attach(springboard, name: "Ruuvi widget system preview")
        XCTAssertTrue(
            text.contains("Sauna") && text.contains("78"), "Missing rendered sensor name or temperature: \(text)")
    }

    @MainActor private func showHomeScreen(_ springboard: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        for _ in 0..<3 {
            let close = springboard.buttons["close"].firstMatch
            guard close.exists && close.isHittable else { break }
            close.tap()
        }
        XCUIDevice.shared.press(.home)
        let done = springboard.buttons["Done"].firstMatch
        if done.exists && done.isHittable { done.tap() }
        XCUIDevice.shared.press(.home)
    }

    private func recognizedText(in screenshot: XCUIScreenshot) throws -> String {
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }

    @MainActor private func attach(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + " accessibility"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
