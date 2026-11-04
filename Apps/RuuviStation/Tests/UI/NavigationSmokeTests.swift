import XCTest

/// Exercises the installed app and retains screenshots in the test result bundle.
/// The existing simulator database is preserved throughout these checks.
final class NavigationSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testDiscoveryAndAboutCanOpenAndDismissWithoutChangingSensors() {
        let app = XCUIApplication()
        app.launch()
        let menu = app.buttons["dashboard.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        let initialCount = app.collectionViews["dashboard.sensors"].cells.count
        menu.tap()
        let discover = app.cells["menu.addSensor"]
        XCTAssertTrue(discover.waitForExistence(timeout: 5))
        discover.tap()
        let closeDiscovery = app.buttons["discover.close"]
        XCTAssertTrue(closeDiscovery.waitForExistence(timeout: 10), app.debugDescription)
        attachScreenshot(app, name: "Sensor discovery")
        closeDiscovery.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let about = app.cells["menu.about"]
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        about.tap()
        XCTAssertTrue(app.textViews["about.details"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "About and database statistics")
        app.buttons["about.close"].tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertEqual(app.collectionViews["dashboard.sensors"].cells.count, initialCount)
    }

    @MainActor func testSettingsNavigationAndReturnToDashboard() throws {
        let app = XCUIApplication()
        app.launch()
        let menu = app.buttons["dashboard.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20), app.debugDescription)
        menu.tap()
        let settings = app.cells["menu.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let list = app.tables["settings.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        for destination in ["units", "resolution", "chart", "appearance", "notifications"] {
            let cell = app.cells["settings." + destination]
            XCTAssertTrue(cell.waitForExistence(timeout: 5), destination)
            cell.tap()
            XCTAssertFalse(app.tables["settings.list"].exists, destination)
            XCTAssertEqual(app.state, .runningForeground)
            attachScreenshot(app, name: destination)
            let back = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            back.tap()
            XCTAssertTrue(list.waitForExistence(timeout: 5))
        }
        app.buttons["settings.close"].tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        attachScreenshot(app, name: "Dashboard after settings navigation")
    }

    @MainActor func testExistingSensorMeasurementGraphAlertsAndSettings() throws {
        let app = XCUIApplication()
        app.launch()
        let dashboard = app.collectionViews["dashboard.sensors"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 20))
        let sensor = dashboard.cells.firstMatch
        guard sensor.waitForExistence(timeout: 10) else {
            throw XCTSkip("This smoke check requires a saved sensor; no simulator data is inserted or deleted.")
        }
        sensor.tap()
        for tab in ["measurement", "graph", "alerts", "settings"] {
            let button = app.buttons["sensor.tab." + tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10), app.debugDescription)
            button.tap()
            XCTAssertEqual(app.state, .runningForeground)
            attachScreenshot(app, name: "Sensor " + tab)
        }
    }

    @MainActor private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
