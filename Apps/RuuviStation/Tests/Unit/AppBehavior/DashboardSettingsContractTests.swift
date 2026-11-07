import Foundation
import RuuviLocal
import RuuviOntology
import XCTest
@testable import station

@MainActor final class DashboardSettingsContractTests: XCTestCase {
    func testRepeatedObservationIsIdempotentAndStoppedServicesDoNotForwardNotifications() {
        let fixture = DashboardSettingsContractFixture()
        defer { fixture.close() }
        fixture.service.startObservingSettings()
        fixture.service.startObservingSettings()
        fixture.center.post(
            name: .DashboardTypeDidChange, object: nil, userInfo: [DashboardTypeKey.type: DashboardType.simple])
        XCTAssertEqual(fixture.output.dashboardTypes, [.simple])
        fixture.service.stopObservingSettings()
        fixture.center.post(
            name: .DashboardTypeDidChange, object: nil, userInfo: [DashboardTypeKey.type: DashboardType.image])
        XCTAssertEqual(fixture.output.dashboardTypes, [.simple])
        fixture.service.startObservingSettings()
        fixture.center.post(
            name: .DashboardTypeDidChange, object: nil, userInfo: [DashboardTypeKey.type: DashboardType.image])
        XCTAssertEqual(fixture.output.dashboardTypes, [.simple, .image])
    }

    func testSettingsNotificationsKeepTheirPayloadAndDraggingSuppressesOnlyOrderChanges() {
        let fixture = DashboardSettingsContractFixture()
        defer { fixture.close() }
        fixture.service.startObservingSettings()
        fixture.center.post(name: .DashboardTypeDidChange, object: nil)
        fixture.center.post(
            name: .DashboardTapActionTypeDidChange, object: nil, userInfo: [DashboardTapActionTypeKey.type: "invalid"])
        XCTAssertTrue(fixture.output.dashboardTypes.isEmpty)
        XCTAssertTrue(fixture.output.tapTypes.isEmpty)
        fixture.center.post(
            name: .DashboardTapActionTypeDidChange, object: nil,
            userInfo: [DashboardTapActionTypeKey.type: DashboardTapActionType.chart])
        XCTAssertEqual(fixture.output.tapTypes, [.chart])
        fixture.service.setUserActivelyDraggingCards(true)
        fixture.center.post(name: .DashboardSensorOrderDidChange, object: nil)
        XCTAssertEqual(fixture.output.orders, 0)
        fixture.center.post(name: .SensorCalibrationDidChange, object: nil)
        XCTAssertEqual(fixture.output.calibrations, 1)
        fixture.service.setUserActivelyDraggingCards(false)
        fixture.center.post(name: .DashboardSensorOrderDidChange, object: nil)
        fixture.service.setSensorOrderResetNeeded()
        XCTAssertEqual(fixture.output.orders, 2)
    }

    func testLanguageUnitsAndWidgetNotificationsPublishTheCurrentSettingsBeforeReloadingBothWidgets() {
        let fixture = DashboardSettingsContractFixture()
        defer { fixture.close() }
        fixture.service.startObservingSettings()
        fixture.settings.temperatureUnit = .fahrenheit
        fixture.settings.humidityUnit = .gm3
        fixture.settings.temperatureAccuracy = .two
        fixture.settings.absoluteHumidityAccuracy = .one
        fixture.center.post(name: .TemperatureUnitDidChange, object: nil)
        XCTAssertEqual(fixture.output.units, 1)
        XCTAssertEqual(fixture.defaults.integer(forKey: AppGroupConstants.temperatureUnitKey), 3)
        XCTAssertEqual(fixture.defaults.integer(forKey: AppGroupConstants.temperatureAccuracyKey), 2)
        XCTAssertEqual(fixture.defaults.integer(forKey: AppGroupConstants.humidityUnitKey), 1)
        XCTAssertEqual(fixture.defaults.integer(forKey: AppGroupConstants.absoluteHumidityAccuracyKey), 1)
        fixture.center.post(name: .LanguageDidChange, object: nil)
        fixture.center.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        XCTAssertEqual(fixture.output.languages, 2)
        fixture.settings.widgetRefreshIntervalMinutes = 30
        fixture.settings.forceRefreshWidget = true
        fixture.center.post(name: .WidgetRefreshIntervalDidChange, object: nil)
        XCTAssertEqual(fixture.defaults.integer(forKey: AppGroupConstants.widgetRefreshIntervalKey), 30)
        XCTAssertTrue(fixture.defaults.bool(forKey: AppGroupConstants.forceRefreshWidgetKey))
        XCTAssertEqual(
            fixture.reloads,
            Array(
                repeating: [AppAssemblyConstants.simpleWidgetKindId, AppAssemblyConstants.multiSensorWidgetKindId],
                count: 4
            ).flatMap { $0 })
    }

    func testDismissedSignInBannerStaysHiddenForTheCurrentAppVersion() {
        let fixture = DashboardSettingsContractFixture()
        defer { fixture.close() }
        fixture.settings.signedInAtleastOnce = true
        XCTAssertTrue(fixture.service.shouldShowSignInBanner(isAuthorized: false, sensorCount: 1))
        XCTAssertFalse(fixture.service.shouldShowSignInBanner(isAuthorized: true, sensorCount: 1))
        XCTAssertFalse(fixture.service.shouldShowSignInBanner(isAuthorized: false, sensorCount: 0))
        fixture.service.hideSignInBanner()
        XCTAssertFalse(fixture.service.shouldShowSignInBanner(isAuthorized: false, sensorCount: 1))
    }
}

@MainActor private final class DashboardSettingsContractFixture {
    let settings = AppTestSettings()
    let center = NotificationCenter()
    let output = DashboardSettingsDelegateSpy()
    let suite = "DashboardSettingsContract." + UUID().uuidString
    let defaults: UserDefaults
    var reloads = [String]()
    var service: DashboardSettingsService!
    init() {
        defaults = UserDefaults(suiteName: suite)!
        service = DashboardSettingsService(
            settings: settings, ruuviAppSettingsService: AppSettingsServiceSpy(settings: settings),
            appGroupDefaults: defaults, notificationCenter: center,
            reloadWidgetTimelines: { [weak self] in self?.reloads.append($0) })
        service.delegate = output
    }
    func close() { service.stopObservingSettings(); defaults.removePersistentDomain(forName: suite) }
}
private final class DashboardSettingsDelegateSpy: DashboardSettingsServiceDelegate {
    var dashboardTypes = [DashboardType]()
    var tapTypes = [DashboardTapActionType]()
    var orders = 0
    var units = 0
    var calibrations = 0
    var languages = 0
    func settingsService(_ service: DashboardSettingsService, dashboardTypeDidChange type: DashboardType) {
        dashboardTypes.append(type)
    }
    func settingsService(_ service: DashboardSettingsService, dashboardTapActionDidChange type: DashboardTapActionType)
    { tapTypes.append(type) }
    func settingsService(_ service: DashboardSettingsService, sensorOrderDidChange: Bool) {
        if sensorOrderDidChange { orders += 1 }
    }
    func settingsService(_ service: DashboardSettingsService, measurementUnitsDidChange: Bool) {
        if measurementUnitsDidChange { units += 1 }
    }
    func settingsService(_ service: DashboardSettingsService, calibrationSettingsDidChange: Bool) {
        if calibrationSettingsDidChange { calibrations += 1 }
    }
    func settingsService(_ service: DashboardSettingsService, languageDidChange: Bool) {
        if languageDidChange { languages += 1 }
    }
}
