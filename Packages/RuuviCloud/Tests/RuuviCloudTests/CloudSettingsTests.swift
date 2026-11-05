import Foundation
import RuuviOntology
import XCTest
@testable import RuuviCloud
#if SWIFT_PACKAGE
    @testable import RuuviCloudApi
#endif

final class CloudSettingsTests: XCTestCase {
    func testUnitSettingsRoundTripEverySupportedUnitAndRejectUnknownValues() {
        for unit: TemperatureUnit in [.celsius, .fahrenheit, .kelvin] {
            XCTAssertEqual(unit.ruuviCloudApiSettingString.ruuviCloudApiSettingUnitTemperature, unit)
        }
        for unit: HumidityUnit in [.percent, .gm3, .dew] {
            XCTAssertEqual(unit.ruuviCloudApiSettingString.ruuviCloudApiSettingUnitHumidity, unit)
        }
        for unit: UnitPressure in [.newtonsPerMetersSquared, .hectopascals, .millimetersOfMercury, .inchesOfMercury] {
            XCTAssertEqual(unit.ruuviCloudApiSettingString.ruuviCloudApiSettingUnitPressure, unit)
        }
        XCTAssertEqual(UnitPressure.kilopascals.ruuviCloudApiSettingString, "")
        for invalid in ["", "unknown", "99"] {
            XCTAssertNil(invalid.ruuviCloudApiSettingUnitTemperature)
            XCTAssertNil(invalid.ruuviCloudApiSettingUnitHumidity)
            XCTAssertNil(invalid.ruuviCloudApiSettingUnitPressure)
        }
    }

    func testLegacyBooleanAccuracyAndDashboardSettingsKeepDocumentedFallbacks() {
        for raw in ["true", "1"] { XCTAssertEqual(raw.ruuviCloudApiSettingBoolean, true) }
        for raw in ["false", "0"] { XCTAssertEqual(raw.ruuviCloudApiSettingBoolean, false) }
        XCTAssertNil("unknown".ruuviCloudApiSettingBoolean)
        for (raw, value): (String, MeasurementAccuracyType) in [("0", .zero), ("1", .one), ("2", .two)] {
            XCTAssertEqual(raw.ruuviCloudApiSettingsMeasurementAccuracyUnitOptional, value)
            XCTAssertEqual(raw.ruuviCloudApiSettingsMeasurementAccuracyUnit, value)
        }
        XCTAssertNil("unknown".ruuviCloudApiSettingsMeasurementAccuracyUnitOptional)
        XCTAssertEqual("unknown".ruuviCloudApiSettingsMeasurementAccuracyUnit, .two)
        for (raw, value): (String, DashboardType) in [("simple", .simple), ("image", .image)] {
            XCTAssertEqual(raw.ruuviCloudApiSettingsDashboardTypeOptional, value)
            XCTAssertEqual(raw.ruuviCloudApiSettingsDashboardType, value)
        }
        XCTAssertNil("unknown".ruuviCloudApiSettingsDashboardTypeOptional)
        XCTAssertEqual("unknown".ruuviCloudApiSettingsDashboardType, .image)
        for (raw, value): (String, DashboardTapActionType) in [("card", .card), ("chart", .chart)] {
            XCTAssertEqual(raw.ruuviCloudApiSettingsDashboardTapActionTypeOptional, value)
            XCTAssertEqual(raw.ruuviCloudApiSettingsDashboardTapActionType, value)
        }
        XCTAssertNil("unknown".ruuviCloudApiSettingsDashboardTapActionTypeOptional)
        XCTAssertEqual("unknown".ruuviCloudApiSettingsDashboardTapActionType, .card)
        XCTAssertEqual("24".ruuviCloudApiSettingChartViewPeriod, 24)
        XCTAssertNil("invalid".ruuviCloudApiSettingChartViewPeriod)
    }

    func testCloudSettingsExposeCorrectTypedValuesAndPreserveMissingValues() {
        let values = SettingsFixture([
            .unitTemperature: "F", .accuracyTemperature: "1", .unitHumidity: "2", .accuracyHumidity: "0",
            .unitPressure: "3", .accuracyPressure: "2", .chartShowAllPoints: "true", .chartDrawDots: "false",
            .chartViewPeriod: "48", .chartShowMinMaxAverage: "true", .cloudModeEnabled: "false",
            .dashboardEnabled: "true", .dashboardType: "simple", .dashboardTapActionType: "chart",
            .pushAlertDisabled: "false", .emailAlertDisabled: "true", .marketingPreference: "true",
            .profileLanguageCode: "FI", .dashboardSensorOrder: "[\"b\",\"a\"]",
        ])
        XCTAssertEqual(values.unitTemperature, .fahrenheit)
        XCTAssertEqual(values.accuracyTemperature, .one)
        XCTAssertEqual(values.unitHumidity, .dew)
        XCTAssertEqual(values.accuracyHumidity, .zero)
        XCTAssertEqual(values.unitPressure, .inchesOfMercury)
        XCTAssertEqual(values.accuracyPressure, .two)
        XCTAssertEqual(values.chartShowAllPoints, true)
        XCTAssertEqual(values.chartDrawDots, false)
        XCTAssertEqual(values.chartViewPeriod, 48)
        XCTAssertEqual(values.chartShowMinMaxAvg, true)
        XCTAssertEqual(values.cloudModeEnabled, false)
        XCTAssertEqual(values.dashboardEnabled, true)
        XCTAssertEqual(values.dashboardType, .simple)
        XCTAssertEqual(values.dashboardTapActionType, .chart)
        XCTAssertEqual(values.pushAlertDisabled, false)
        XCTAssertEqual(values.emailAlertDisabled, true)
        XCTAssertEqual(values.marketingPreference, true)
        XCTAssertEqual(values.profileLanguageCode, "FI")
        XCTAssertEqual(values.dashboardSensorOrder, "[\"b\",\"a\"]")
        let empty = SettingsFixture([:])
        XCTAssertNil(empty.unitTemperature)
        XCTAssertNil(empty.accuracyTemperature)
        XCTAssertNil(empty.unitHumidity)
        XCTAssertNil(empty.accuracyHumidity)
        XCTAssertNil(empty.unitPressure)
        XCTAssertNil(empty.accuracyPressure)
        XCTAssertNil(empty.dashboardType)
        XCTAssertNil(empty.dashboardTapActionType)
        XCTAssertNil(empty.chartViewPeriod)
        XCTAssertNil(empty.profileLanguageCode)
        XCTAssertNil(empty.dashboardSensorOrder)
        for path: KeyPath<SettingsFixture, Bool?> in [
            \.chartShowAllPoints, \.chartDrawDots, \.chartShowMinMaxAvg,
            \.cloudModeEnabled, \.dashboardEnabled, \.pushAlertDisabled,
            \.emailAlertDisabled, \.marketingPreference,
        ] {
            XCTAssertNil(empty[keyPath: path])
        }
        for key in RuuviCloudApiSetting.allCases {
            let excluded: Set<RuuviCloudApiSetting> = [
                .chartViewPeriod, .marketingPreference, .sensorDisplayOrder,
                .sensorDefaultDisplayOrder, .sensorDescription,
            ]
            XCTAssertEqual(key.isCloudSyncedUserSetting, !excluded.contains(key), key.rawValue)
        }
    }

    func testSensorOrderJSONRoundTripsUnicodeQuotesAndEmptyLists() throws {
        for values in [[], ["Sauna", "Room & sensor"], ["温度", "a\"b", "a\\b", "\n"]] {
            let encoded = try XCTUnwrap(RuuviCloudApiHelper.jsonStringFromArray(values))
            XCTAssertEqual(RuuviCloudApiHelper.jsonArrayFromString(encoded), values)
        }
        for invalid in ["", "null", "{}", "[1]", "invalid"] {
            XCTAssertNil(RuuviCloudApiHelper.jsonArrayFromString(invalid), invalid)
        }
    }
}

private struct SettingsFixture: RuuviCloudSettings {
    let userSettings: [RuuviUserSetting]
    init(_ values: [RuuviCloudApiSetting: String]) {
        userSettings = values.map { RuuviUserSettingStruct(key: $0.key.rawValue, value: $0.value, lastUpdated: nil) }
    }
}
