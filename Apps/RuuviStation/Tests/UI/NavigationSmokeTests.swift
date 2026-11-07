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
        for destination in ["units", "resolution", "heartbeat", "chart", "appearance", "notifications"] {
            let cell = app.cells["settings." + destination]
            XCTAssertTrue(cell.waitForExistence(timeout: 5), destination)
            if !cell.isHittable { list.swipeUp() }
            cell.tap()
            XCTAssertTrue(list.waitForNonExistence(timeout: 5), destination + "\n" + app.debugDescription)
            XCTAssertEqual(app.state, .runningForeground)
            attachScreenshot(app, name: destination)
            switch destination {
            case "units": inspectChoices(app, parent: "settings.unitConfiguration", choices: "settings.selection")
            case "appearance":
                inspectChoices(app, parent: "settings.appearanceOptions", choices: "settings.themeChoices")
            case "notifications":
                inspectChoices(
                    app, parent: "settings.notificationOptions", choices: "settings.soundChoices",
                    rowID: "settings.alertSound")
            default: break
            }
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
        let back = app.buttons["sensor.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(dashboard.waitForExistence(timeout: 10))
        XCTAssertTrue(sensor.waitForExistence(timeout: 5))
        sensor.tap()
        XCTAssertTrue(app.buttons["sensor.tab.measurement"].waitForExistence(timeout: 10))
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(dashboard.waitForExistence(timeout: 10))
        attachScreenshot(app, name: "Dashboard after reopening and closing sensor")
    }

    @MainActor func testSensorMeasurementAndGraphSurviveLandscapeAndReturnToPortrait() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let dashboard = app.collectionViews["dashboard.sensors"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 20))
        let sensor = dashboard.cells.firstMatch
        guard sensor.waitForExistence(timeout: 10) else {
            throw XCTSkip("Rotation smoke check requires a saved sensor.")
        }
        sensor.tap()
        for tab in ["measurement", "graph"] {
            let button = app.buttons["sensor.tab." + tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
            XCUIDevice.shared.orientation = .landscapeLeft
            let landscape = NSPredicate { _, _ in app.frame.width > app.frame.height }
            XCTAssertEqual(
                XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: landscape, object: app)], timeout: 10),
                .completed)
            XCTAssertTrue(button.isHittable)
            XCTAssertTrue(app.buttons["sensor.back"].isHittable)
            attachScreenshot(app, name: "Landscape sensor " + tab)
            XCUIDevice.shared.orientation = .portrait
            let portrait = NSPredicate { _, _ in app.frame.height > app.frame.width }
            XCTAssertEqual(
                XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: portrait, object: app)], timeout: 10),
                .completed)
            XCTAssertTrue(button.isHittable)
        }
        app.buttons["sensor.back"].tap()
        XCTAssertTrue(dashboard.waitForExistence(timeout: 10))
    }

    @MainActor private func inspectChoices(
        _ app: XCUIApplication, parent: String, choices: String, rowID: String? = nil
    ) {
        let table = app.tables[parent]
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        let row = rowID.map { table.cells[$0] } ?? table.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        if !row.isHittable { table.swipeUp() }
        let originalLabel = row.label
        row.tap()
        let picker = app.tables[choices]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertGreaterThan(picker.cells.count, 1)
        attachScreenshot(app, name: choices)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        XCTAssertEqual(row.label, originalLabel, "Opening and cancelling a picker must keep its selection")
    }

    @MainActor private func attachScreenshot(_: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
