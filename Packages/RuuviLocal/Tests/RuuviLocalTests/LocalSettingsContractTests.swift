import Foundation
import RuuviLocal
#if SWIFT_PACKAGE
    @testable import RuuviLocalUserDefaults
#else
    @testable import RuuviLocal
#endif
import RuuviOntology
import XCTest

final class LocalSettingsContractTests: XCTestCase {
    private var previous: [String: Any] = [:]
    private var domain = ""
    private let prefixes = ["SettingsUserDefaults.", "SettingsUserDegaults.", "DashboardScrollViewController."]

    override func setUp() {
        super.setUp()
        domain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let defaults = UserDefaults.standard
        previous = defaults.persistentDomain(forName: domain) ?? [:]
        // Replace once: removing thousands of stale per-sensor keys individually can
        // cross CFPreferences' size limit while a previous test domain is being restored.
        defaults.setPersistentDomain(
            previous.filter { key, _ in
                !prefixes.contains { key.hasPrefix($0) }
            }, forName: domain)
    }

    override func tearDown() {
        UserDefaults.standard.setPersistentDomain(previous, forName: domain)
        super.tearDown()
    }

    func testCloudLanguageAndWidgetNavigationHaveIndependentPersistentStorage() {
        let settings = RuuviLocalSettingsUserDefaults()
        XCTAssertNil(settings.cloudProfileLanguageCode)
        XCTAssertNil(settings.cardToOpenFromWidget())
        settings.cloudProfileLanguageCode = "fi"
        XCTAssertNil(settings.cardToOpenFromWidget())
        settings.setCardToOpenFromWidget(for: "AA:BB:CC:DD:EE:01")
        XCTAssertEqual(settings.cloudProfileLanguageCode, "fi")
        XCTAssertEqual(RuuviLocalSettingsUserDefaults().cardToOpenFromWidget(), "AA:BB:CC:DD:EE:01")
        settings.cloudProfileLanguageCode = nil
        XCTAssertEqual(settings.cardToOpenFromWidget(), "AA:BB:CC:DD:EE:01")
        settings.cloudProfileLanguageCode = "en"
        settings.resetCloudProfileSettings()
        XCTAssertNil(settings.cloudProfileLanguageCode)
        XCTAssertNil(settings.cardToOpenFromWidget())
    }

    func testTemperatureAndHumidityUnitsRoundTripAndLegacyDefaultsArePreserved() {
        let settings = RuuviLocalSettingsUserDefaults()
        for unit: TemperatureUnit in [.kelvin, .celsius, .fahrenheit] {
            settings.temperatureUnit = unit
            XCTAssertEqual(RuuviLocalSettingsUserDefaults().temperatureUnit, unit)
        }
        for unit: HumidityUnit in [.percent, .gm3, .dew] {
            settings.humidityUnit = unit
            XCTAssertEqual(RuuviLocalSettingsUserDefaults().humidityUnit, unit)
        }
        for legacy in [false, true] {
            UserDefaults.standard.removeObject(forKey: "SettingsUserDegaults.temperatureUnitIntUDKey")
            UserDefaults.standard.set(legacy, forKey: "SettingsUserDegaults.useFahrenheit")
            XCTAssertEqual(settings.temperatureUnit, legacy ? .fahrenheit : .celsius)
        }
        UserDefaults.standard.removeObject(forKey: "SettingsUserDegaults.temperatureUnitIntUDKey")
        UserDefaults.standard.removeObject(forKey: "SettingsUserDegaults.useFahrenheit")
        settings.appOpenedCount = 1
        XCTAssertEqual(settings.temperatureUnit, .celsius)
        UserDefaults.standard.set(999, forKey: "SettingsUserDegaults.temperatureUnitIntUDKey")
        UserDefaults.standard.set(999, forKey: "SettingsUserDegaults.humidityUnitInt")
        XCTAssertEqual(settings.temperatureUnit, .celsius)
        XCTAssertEqual(settings.humidityUnit, .percent)
    }

    func testLegacyCloudLanguageMovesToItsOwnKeyWithoutChangingAWidgetDestination() {
        let defaults = UserDefaults.standard
        let oldKey = "SettingsUserDefaults.cardToOpenFromWidgetKey"
        let newKey = "SettingsUserDefaults.cloudProfileLanguageCode"
        for language in Language.allCases {
            defaults.removeObject(forKey: newKey)
            defaults.set(language.rawValue, forKey: oldKey)
            let settings = RuuviLocalSettingsUserDefaults()
            XCTAssertNil(settings.cardToOpenFromWidget())
            XCTAssertEqual(settings.cloudProfileLanguageCode, language.rawValue)
            XCTAssertNil(defaults.object(forKey: oldKey))
        }
        defaults.set("en", forKey: newKey)
        defaults.set("fi", forKey: oldKey)
        let settings = RuuviLocalSettingsUserDefaults()
        XCTAssertEqual(settings.cloudProfileLanguageCode, "en")
        defaults.removeObject(forKey: newKey)
        defaults.set("AA:BB:CC:DD:EE:01", forKey: oldKey)
        XCTAssertNil(settings.cloudProfileLanguageCode)
        XCTAssertEqual(settings.cardToOpenFromWidget(), "AA:BB:CC:DD:EE:01")
        defaults.set("fi", forKey: oldKey)
        settings.setCardToOpenFromWidget(for: "AA:BB:CC:DD:EE:02")
        XCTAssertEqual(settings.cloudProfileLanguageCode, "fi")
        XCTAssertEqual(settings.cardToOpenFromWidget(), "AA:BB:CC:DD:EE:02")
    }

    func testOptionalPreferencesRemoveNilValuesAndRecoverFromUnexpectedStoredTypes() {
        let key = "SettingsUserDefaults.optional-test"
        var preference = UserDefault<String?>(key, defaultValue: nil)
        XCTAssertNil(preference.wrappedValue)
        preference.wrappedValue = "value"
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "value")
        XCTAssertEqual(preference.wrappedValue, "value")
        preference.wrappedValue = nil
        XCTAssertNil(UserDefaults.standard.object(forKey: key))
        XCTAssertNil(preference.wrappedValue)
        UserDefaults.standard.set([1, 2], forKey: key)
        XCTAssertNil(preference.wrappedValue)
    }

    func testEveryMeasurementAccuracyPersistsAndHumidityDefaultsMigrateIndependently() {
        let settings = RuuviLocalSettingsUserDefaults()
        let paths: [ReferenceWritableKeyPath<RuuviLocalSettingsUserDefaults, MeasurementAccuracyType>] = [
            \.temperatureAccuracy, \.humidityAccuracy, \.pressureAccuracy, \.relativeHumidityAccuracy,
            \.absoluteHumidityAccuracy, \.dewPointAccuracy, \.pmAccuracy, \.accelerationAccuracy, \.voltageAccuracy,
        ]
        for value: MeasurementAccuracyType in [.zero, .one, .two] {
            for path in paths {
                settings[keyPath: path] = value
                XCTAssertEqual(RuuviLocalSettingsUserDefaults()[keyPath: path], value)
            }
        }
        settings.humidityAccuracy = .one
        XCTAssertEqual(settings.relativeHumidityAccuracy, .one)
        XCTAssertEqual(settings.absoluteHumidityAccuracy, .one)
        XCTAssertEqual(settings.dewPointAccuracy, .one)
        settings.relativeHumidityAccuracy = .zero
        XCTAssertEqual(settings.absoluteHumidityAccuracy, .one)
        XCTAssertEqual(settings.dewPointAccuracy, .one)
        for key in [
            "temperatureAccuracyInt", "humidityAccuracyInt", "pressureAccuracyInt",
            "relativeHumidityAccuracyInt", "absoluteHumidityAccuracyInt", "dewPointAccuracyInt",
            "pmAccuracyInt", "accelerationAccuracyInt", "voltageAccuracyInt",
        ] {
            UserDefaults.standard.set(99, forKey: "SettingsUserDefaults." + key)
        }
        for path in paths { XCTAssertEqual(settings[keyPath: path], .two) }
    }

    func testSensorSpecificPreferencesDoNotLeakBetweenSensorsAndCanBeRemoved() {
        let settings = RuuviLocalSettingsUserDefaults()
        let first = UUID().uuidString.luid
        let second = UUID().uuidString.luid
        let mac = "AA:BB:CC:DD:EE:01".mac
        XCTAssertFalse(settings.keepConnectionDialogWasShown(for: first))
        XCTAssertFalse(settings.firmwareUpdateDialogWasShown(for: first))
        XCTAssertFalse(settings.syncDialogHidden(for: first))
        settings.setKeepConnectionDialogWasShown(true, for: first)
        settings.setFirmwareUpdateDialogWasShown(true, for: first)
        settings.setSyncDialogHidden(true, for: first)
        XCTAssertTrue(settings.keepConnectionDialogWasShown(for: first))
        XCTAssertTrue(settings.firmwareUpdateDialogWasShown(for: first))
        XCTAssertTrue(settings.syncDialogHidden(for: first))
        XCTAssertFalse(settings.keepConnectionDialogWasShown(for: second))
        XCTAssertFalse(settings.firmwareUpdateDialogWasShown(for: second))
        XCTAssertFalse(settings.syncDialogHidden(for: second))
        settings.setFirmwareVersion(for: first, value: "3.31.0")
        XCTAssertEqual(settings.firmwareVersion(for: first), "3.31.0")
        XCTAssertNil(settings.firmwareVersion(for: second))
        settings.setFirmwareVersion(for: first, value: nil)
        XCTAssertNil(settings.firmwareVersion(for: first))
        XCTAssertNil(settings.ownerCheckDate(for: mac))
        let date = Date(timeIntervalSince1970: 1234)
        settings.setOwnerCheckDate(for: mac, value: date)
        XCTAssertEqual(settings.ownerCheckDate(for: mac), date)
        settings.setOwnerCheckDate(for: mac, value: nil)
        settings.setOwnerCheckDate(for: nil, value: date)
        XCTAssertNil(settings.ownerCheckDate(for: mac))
        XCTAssertNil(settings.ownerCheckDate(for: nil))
        for brightness: RuuviLedBrightnessLevel in [.off, .dim, .normal, .bright] {
            settings.setLedBrightnessSelection(brightness, for: mac)
            XCTAssertEqual(settings.ledBrightnessSelection(for: mac), brightness)
        }
        settings.setLedBrightnessSelection(nil, for: mac)
        settings.setLedBrightnessSelection(.bright, for: nil)
        XCTAssertNil(settings.ledBrightnessSelection(for: mac))
        XCTAssertNil(settings.ledBrightnessSelection(for: nil))
        UserDefaults.standard.set(99, forKey: "SettingsUserDefaults.ledBrightnessSelection." + mac.value)
        XCTAssertNil(settings.ledBrightnessSelection(for: mac))
    }
}

extension LocalSettingsContractTests {
    func testDashboardThemeAndAlertPreferencesNotifyAfterPersistingAndRecoverUnknownValues() {
        let settings = RuuviLocalSettingsUserDefaults()
        for value: DashboardType in [.image, .simple] {
            settings.dashboardType = value
            XCTAssertEqual(RuuviLocalSettingsUserDefaults().dashboardType, value)
        }
        for value: DashboardTapActionType in [.card, .chart] {
            settings.dashboardTapActionType = value
            XCTAssertEqual(RuuviLocalSettingsUserDefaults().dashboardTapActionType, value)
        }
        for value: RuuviTheme in [.system, .light, .dark] {
            settings.theme = value
            XCTAssertEqual(RuuviLocalSettingsUserDefaults().theme, value)
        }
        for value: RuuviAlertSound in [.systemDefault, .ruuviSpeak] {
            settings.alertSound = value
            XCTAssertEqual(RuuviLocalSettingsUserDefaults().alertSound, value)
        }
        settings.dashboardSensorOrder = ["second", "first"]
        XCTAssertEqual(RuuviLocalSettingsUserDefaults().dashboardSensorOrder, ["second", "first"])
        let defaults = UserDefaults.standard
        for key in ["dashboardTypeIdKey", "dashboardTapActionTypeIdKey", "ruuviThemeIdKey"] {
            defaults.set(99, forKey: "SettingsUserDefaults." + key)
        }
        defaults.set("unknown", forKey: "SettingsUserDefaults.ruuviAlertSoundKey")
        XCTAssertEqual(settings.dashboardType, .image)
        XCTAssertEqual(settings.dashboardTapActionType, .card)
        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.alertSound, .ruuviSpeak)
        defaults.removeObject(forKey: "SettingsUserDefaults.ruuviAlertSoundKey")
        XCTAssertEqual(settings.alertSound, .ruuviSpeak)
    }

    func testSettingsNotificationsContainThePersistedValueAndCorrectMetadata() {
        let settings = RuuviLocalSettingsUserDefaults()
        let names: [Notification.Name] = [
            .DashboardTypeDidChange, .DashboardTapActionTypeDidChange,
            .AppearanceSettingsDidChange, .AlertSoundSettingsDidChange,
            .DashboardSensorOrderDidChange, .TemperatureUnitDidChange,
            .HumidityUnitDidChange, .PressureUnitDidChange,
        ]
        var received: [Notification] = []
        let tokens = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { received.append($0) }
        }
        defer { tokens.forEach(NotificationCenter.default.removeObserver) }
        settings.dashboardType = .simple
        settings.dashboardTapActionType = .chart
        settings.theme = .dark
        settings.alertSound = .systemDefault
        settings.dashboardSensorOrder = ["sensor"]
        settings.temperatureUnit = .fahrenheit
        settings.humidityUnit = .dew
        settings.pressureUnit = .inchesOfMercury
        XCTAssertEqual(received.map(\.name), names)
        XCTAssertEqual(received[0].userInfo?[DashboardTypeKey.type] as? DashboardType, .simple)
        XCTAssertEqual(received[1].userInfo?[DashboardTapActionTypeKey.type] as? DashboardTapActionType, .chart)
        XCTAssertEqual(received[2].userInfo?[AppearanceTypeKey.style] as? RuuviTheme, .dark)
        XCTAssertEqual(received[3].userInfo?[AppearanceTypeKey.style] as? RuuviAlertSound, .systemDefault)
        XCTAssertTrue(received.allSatisfy { ($0.object as? RuuviLocalSettingsUserDefaults) === settings })
    }

    func testCloudAlertPreferenceNotificationsAreDeliveredForEachSetting() async {
        let settings = RuuviLocalSettingsUserDefaults()
        let rows: [(Notification.Name, ReferenceWritableKeyPath<RuuviLocalSettingsUserDefaults, Bool>)] = [
            (.EmailAlertSettingsDidChange, \.emailAlertDisabled), (.PushAlertSettingsDidChange, \.pushAlertDisabled),
            (.MarketingPreferenceDidChange, \.marketingPreference),
            (.LimitAlertNotificationsSettingsDidChange, \.limitAlertNotificationsEnabled),
        ]
        for (name, path) in rows {
            let expected = !settings[keyPath: path]
            let notified = expectation(description: name.rawValue)
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { event in
                XCTAssertTrue((event.object as? RuuviLocalSettingsUserDefaults) === settings)
                XCTAssertEqual(settings[keyPath: path], expected)
                notified.fulfill()
            }
            settings[keyPath: path] = expected
            await fulfillment(of: [notified], timeout: 2)
            NotificationCenter.default.removeObserver(token)
            XCTAssertEqual(RuuviLocalSettingsUserDefaults()[keyPath: path], expected)
        }
    }

    func testChartMigrationClampsSizesAndPreservesExistingExplicitChoices() {
        let defaults = UserDefaults.standard
        let settings = RuuviLocalSettingsUserDefaults()
        for compact in [true, false] {
            defaults.removeObject(forKey: "SettingsUserDefaults.chartsPerScreen")
            defaults.set(compact, forKey: "SettingsUserDefaults.compactChatView")
            XCTAssertEqual(settings.chartsPerScreen, compact ? 3 : 1)
            XCTAssertNil(defaults.object(forKey: "SettingsUserDefaults.compactChatView"))
        }
        for (requested, expected) in [(-10, 1), (1, 1), (2, 2), (3, 3), (100, 3)] {
            settings.chartsPerScreen = requested
            XCTAssertEqual(RuuviLocalSettingsUserDefaults().chartsPerScreen, expected)
        }
        settings.setLastOpenedChart(with: "sensor")
        XCTAssertEqual(settings.lastOpenedChart(), "sensor")
        settings.setLastOpenedChart(with: nil)
        XCTAssertNil(settings.lastOpenedChart())
    }

    func testPerSensorCustomBoundsAndVersionBannerPreferencesRemainIndependent() {
        let settings = RuuviLocalSettingsUserDefaults()
        for id in ["sensor-one", "sensor-two"] {
            XCTAssertFalse(settings.showCustomTempAlertBound(for: id))
            XCTAssertFalse(settings.showCustomCO2AlertBound(for: id))
            XCTAssertFalse(settings.showCustomPMAlertBound(for: id))
        }
        settings.setShowCustomTempAlertBound(true, for: "sensor-one")
        settings.setShowCustomCO2AlertBound(true, for: "sensor-one")
        settings.setShowCustomPMAlertBound(true, for: "sensor-one")
        XCTAssertTrue(settings.showCustomTempAlertBound(for: "sensor-one"))
        XCTAssertTrue(settings.showCustomCO2AlertBound(for: "sensor-one"))
        XCTAssertTrue(settings.showCustomPMAlertBound(for: "sensor-one"))
        XCTAssertFalse(settings.showCustomTempAlertBound(for: "sensor-two"))
        XCTAssertFalse(settings.showCustomCO2AlertBound(for: "sensor-two"))
        XCTAssertFalse(settings.showCustomPMAlertBound(for: "sensor-two"))
        XCTAssertFalse(settings.dashboardSignInBannerHidden(for: "3.0.0"))
        settings.setDashboardSignInBannerHidden(for: "3.0.0")
        XCTAssertTrue(settings.dashboardSignInBannerHidden(for: "3.0.0"))
        XCTAssertFalse(settings.dashboardSignInBannerHidden(for: "3.1.0"))
    }

    func testMovementHysteresisDatesRoundTripAndIgnoreMalformedLegacyValues() {
        let settings = RuuviLocalSettingsUserDefaults()
        XCTAssertEqual(settings.movementAlertHysteresisLastEvents(), [:])
        let dates = ["first": Date(timeIntervalSince1970: 123), "second": Date(timeIntervalSince1970: 456)]
        settings.setMovementAlertHysteresisLastEvents(dates)
        XCTAssertEqual(settings.movementAlertHysteresisLastEvents(), dates)
        UserDefaults.standard.set(
            ["first": 123.0, "invalid": "no date"],
            forKey: "SettingsUserDefaults.movementAlertHysteresisLastEvents")
        XCTAssertEqual(settings.movementAlertHysteresisLastEvents(), ["first": Date(timeIntervalSince1970: 123)])
    }

    func testPressureUnitsRoundTripThroughEverySupportedRepresentation() {
        let settings = RuuviLocalSettingsUserDefaults()
        for value: UnitPressure in [.hectopascals, .newtonsPerMetersSquared, .inchesOfMercury, .millimetersOfMercury] {
            settings.pressureUnit = value
            XCTAssertEqual(RuuviLocalSettingsUserDefaults().pressureUnit, value)
        }
        UserDefaults.standard.set(999, forKey: "SettingsUserDefaults.pressureUnitInt")
        XCTAssertEqual(settings.pressureUnit, .hectopascals)
    }

    func testLanguageAndBadgeValuesPersistInTheSharedNotificationSuite() throws {
        let suite = "ruuvi-language-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = RuuviLocalSettingsUserDefaults(notificationServiceDefaults: defaults)
        XCTAssertEqual(settings.language, .english)
        XCTAssertEqual(settings.notificationsBadgeCount(), 0)
        for language in Language.allCases {
            settings.language = language
            XCTAssertEqual(settings.language, language)
            XCTAssertEqual(
                RuuviLocalSettingsUserDefaults(notificationServiceDefaults: defaults).language, language)
            XCTAssertEqual(
                UserDefaults.standard.string(forKey: "SettingsUserDegaults.languageUDKey"), language.rawValue)
        }
        defaults.set("unknown", forKey: "SettingsUserDegaults.languageUDKey")
        XCTAssertEqual(settings.language, .english)
        settings.setNotificationsBadgeCount(value: 9)
        XCTAssertEqual(settings.notificationsBadgeCount(), 9)
        settings.setNotificationsBadgeCount(value: 0)
        XCTAssertEqual(settings.notificationsBadgeCount(), 0)
        let unavailable = RuuviLocalSettingsUserDefaults(notificationServiceDefaults: nil)
        unavailable.setNotificationsBadgeCount(value: 1)
        XCTAssertEqual(unavailable.notificationsBadgeCount(), 0)
        XCTAssertEqual(unavailable.language, .english)
    }

    func testGraphCloudAndDaemonChangesNotifyObserversAfterPersistence() {
        let settings = RuuviLocalSettingsUserDefaults()
        let booleans: [(Notification.Name, ReferenceWritableKeyPath<RuuviLocalSettingsUserDefaults, Bool>)] = [
            (.isAdvertisementDaemonOnDidChange, \.isAdvertisementDaemonOn),
            (.DownsampleOnDidChange, \.chartShowAllMeasurements),
            (.ChartDrawDotsOnDidChange, \.chartDrawDotsOn),
            (.ChartStatsOnDidChange, \.chartStatsOn),
            (.CloudModeDidChange, \.cloudModeEnabled),
        ]
        for (name, path) in booleans {
            let value = !settings[keyPath: path]
            var notifications = 0
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { _ in
                notifications += 1
                XCTAssertEqual(RuuviLocalSettingsUserDefaults()[keyPath: path], value)
            }
            settings[keyPath: path] = value
            XCTAssertEqual(notifications, 1)
            NotificationCenter.default.removeObserver(token)
        }
        let integers: [(Notification.Name, ReferenceWritableKeyPath<RuuviLocalSettingsUserDefaults, Int>)] = [
            (.ChartDurationHourDidChange, \.chartDurationHours),
            (.WidgetRefreshIntervalDidChange, \.widgetRefreshIntervalMinutes),
        ]
        for (name, path) in integers {
            var notifications = 0
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { _ in
                notifications += 1
                XCTAssertEqual(RuuviLocalSettingsUserDefaults()[keyPath: path], 120)
            }
            settings[keyPath: path] = 120
            XCTAssertEqual(notifications, 1)
            NotificationCenter.default.removeObserver(token)
        }
    }

}
