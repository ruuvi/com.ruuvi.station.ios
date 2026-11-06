import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import XCTest
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviLocalUserDefaults
    @testable import RuuviServiceCloudSync
#endif

final class CloudUserSettingsTests: XCTestCase {
    private var previous = [String: Any]()
    private var domain = ""
    private var settings: RuuviLocalSettings!

    override func setUp() {
        super.setUp()
        domain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        previous = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
        settings = RuuviLocalFactoryUserDefaults().createLocalSettings()
    }

    override func tearDown() {
        UserDefaults.standard.setPersistentDomain(previous, forName: domain)
        settings = nil
        super.tearDown()
    }

    func testMeasurementUnitsAndPrecisionApplyAndSerializeWithoutLosingTheirTimestamp() throws {
        let cases: [(RuuviCloudApiSetting, [String])] = [
            (.unitTemperature, ["C", "F", "K"]), (.unitHumidity, ["0", "1", "2"]),
            (.unitPressure, ["0", "1", "2", "3"]),
            (.accuracyTemperature, ["0", "1", "2"]), (.accuracyHumidity, ["0", "1", "2"]),
            (.accuracyHumidityRelative, ["0", "1", "2"]),
            (.accuracyHumidityAbsolute, ["0", "1", "2"]),
            (.accuracyHumidityDewPoint, ["0", "1", "2"]),
            (.accuracyPressure, ["0", "1", "2"]), (.accuracyPM, ["0", "1", "2"]),
            (.accuracyAcceleration, ["0", "1", "2"]), (.accuracyVoltage, ["0", "1", "2"]),
        ]
        settings.humidityAccuracy = .zero
        for (key, values) in cases {
            for value in values {
                try assertApplyAndSerialize(key, value: value)
            }
            let saved = key.localValue(from: settings)
            XCTAssertFalse(key.apply(value: "invalid", to: settings), key.rawValue)
            XCTAssertEqual(key.localValue(from: settings), saved, key.rawValue)
        }
        XCTAssertEqual(settings.temperatureUnit, .kelvin)
        XCTAssertEqual(settings.humidityUnit, .dew)
        XCTAssertEqual(settings.pressureUnit, .inchesOfMercury)
        XCTAssertEqual(settings.pmAccuracy, .two)
    }

    func testLegacyHumidityPrecisionCannotOverwriteIndividuallyConfiguredPrecisions() {
        settings.relativeHumidityAccuracy = .zero
        settings.absoluteHumidityAccuracy = .one
        settings.dewPointAccuracy = .two
        XCTAssertFalse(RuuviCloudApiSetting.accuracyHumidity.apply(value: "2", to: settings))
        XCTAssertEqual(settings.relativeHumidityAccuracy, .zero)
        XCTAssertEqual(settings.absoluteHumidityAccuracy, .one)
        XCTAssertEqual(settings.dewPointAccuracy, .two)
    }

    func testDashboardChartAndNotificationPreferencesRejectInvalidValuesAndApplyIdempotently() throws {
        let booleanKeys: [RuuviCloudApiSetting] = [
            .chartShowAllPoints, .chartShowMinMaxAverage, .cloudModeEnabled, .dashboardEnabled,
            .emailAlertDisabled, .pushAlertDisabled, .marketingPreference,
        ]
        for key in booleanKeys {
            try assertApplyAndSerialize(key, value: "false")
            try assertApplyAndSerialize(key, value: "true")
            XCTAssertFalse(key.apply(value: "invalid", to: settings), key.rawValue)
            XCTAssertEqual(key.localValue(from: settings), "true")
        }
        XCTAssertFalse(settings.chartDownsamplingOn)
        XCTAssertTrue(settings.chartStatsOn)
        for (key, values): (RuuviCloudApiSetting, [String]) in [
            (.dashboardType, ["image", "simple"]), (.dashboardTapActionType, ["card", "chart"]),
        ] {
            for value in values { try assertApplyAndSerialize(key, value: value) }
            XCTAssertFalse(key.apply(value: "invalid", to: settings))
        }
        XCTAssertEqual(settings.dashboardType, .simple)
        XCTAssertEqual(settings.dashboardTapActionType, .chart)
    }

    func testCloudCannotReenableChartDotsButCanDisablePreviouslyStoredDots() {
        let key = RuuviCloudApiSetting.chartDrawDots
        settings.chartDrawDotsOn = false
        key.apply(value: "true", to: settings)
        XCTAssertFalse(settings.chartDrawDotsOn)
        XCTAssertFalse(key.apply(value: "invalid", to: settings))
        XCTAssertFalse(key.apply(value: "false", to: settings))
        settings.chartDrawDotsOn = true
        XCTAssertTrue(key.apply(value: "false", to: settings))
        XCTAssertFalse(settings.chartDrawDotsOn)
        XCTAssertEqual(key.localValue(from: settings), "false")
    }

    func testLanguageFallbackAndSensorOrderPreserveTheirSeparateContracts() throws {
        settings.cloudProfileLanguageCode = nil
        let language = RuuviCloudApiSetting.profileLanguageCode
        XCTAssertEqual(language.localValue(from: settings), settings.language.rawValue)
        try assertApplyAndSerialize(language, value: "FI")
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let fallback = try XCTUnwrap(language.missingCloudUserSetting(from: settings, lastUpdated: timestamp))
        XCTAssertEqual(fallback.key, language.rawValue)
        XCTAssertEqual(fallback.value, settings.language.rawValue)
        XCTAssertEqual(fallback.lastUpdated, timestamp)
        XCTAssertTrue(language.applyMissingCloudValue(to: settings))
        XCTAssertFalse(language.applyMissingCloudValue(to: settings))
        let order = RuuviCloudApiSetting.dashboardSensorOrder
        try assertApplyAndSerialize(order, value: "[\"sensor-b\",\"sensor-a\"]")
        XCTAssertEqual(settings.dashboardSensorOrder, ["sensor-b", "sensor-a"])
        XCTAssertFalse(order.apply(value: "[17]", to: settings))
        XCTAssertFalse(order.apply(value: "{\"id\":1}", to: settings))
        XCTAssertEqual(settings.dashboardSensorOrder, ["sensor-b", "sensor-a"])
        XCTAssertNil(order.missingCloudUserSetting(from: settings))
        XCTAssertFalse(order.applyMissingCloudValue(to: settings))
    }

    func testPerSensorKeysChartDurationAndMismatchedRecordsCannotMutateGlobalSettings() {
        let before = settings.temperatureUnit
        let wrong = RuuviUserSettingStruct(key: "unrelated", value: "F", lastUpdated: nil)
        XCTAssertFalse(RuuviCloudApiSetting.unitTemperature.apply(userSetting: wrong, to: settings))
        XCTAssertEqual(settings.temperatureUnit, before)
        for key: RuuviCloudApiSetting in [
            .sensorDescription, .sensorDisplayOrder, .sensorDefaultDisplayOrder, .chartViewPeriod,
        ] {
            XCTAssertFalse(key.isAppliedFromCloud)
            XCTAssertNil(key.localValue(from: settings))
            XCTAssertNil(key.userSetting(from: settings))
            XCTAssertNil(key.missingCloudUserSetting(from: settings))
            XCTAssertFalse(key.apply(value: "24", to: settings))
        }
        XCTAssertFalse(RuuviCloudApiSetting.marketingPreference.isAppliedFromCloud)
        XCTAssertTrue(RuuviCloudApiSetting.unitTemperature.isAppliedFromCloud)
    }

    private func assertApplyAndSerialize(_ key: RuuviCloudApiSetting, value: String) throws {
        let previous = key.localValue(from: settings)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let setting = RuuviUserSettingStruct(key: key.rawValue, value: value, lastUpdated: timestamp)
        XCTAssertEqual(key.apply(userSetting: setting, to: settings), previous != value, key.rawValue)
        XCTAssertEqual(key.localValue(from: settings), value, key.rawValue)
        XCTAssertFalse(key.apply(userSetting: setting, to: settings), key.rawValue)
        let encoded = try XCTUnwrap(key.userSetting(from: settings, lastUpdated: timestamp))
        XCTAssertEqual(encoded.key, key.rawValue)
        XCTAssertEqual(encoded.value, value)
        XCTAssertEqual(encoded.lastUpdated, timestamp)
    }
}
