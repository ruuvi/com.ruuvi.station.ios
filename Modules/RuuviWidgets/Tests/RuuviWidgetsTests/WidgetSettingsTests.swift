import Foundation
import RuuviLocalization
import RuuviOntology
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetSettingsTests: XCTestCase {
    func testMissingOrCorruptAccuracySettingsUseDefaults() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        for key: Constants in [.temperatureAccuracyKey, .humidityAccuracyKey, .pressureAccuracyKey] {
            fixture.defaults.removeObject(forKey: key.rawValue)
        }
        var settings = fixture.model.getAppSettings()
        XCTAssertEqual(settings.temperatureAccuracy, .two)
        XCTAssertEqual(settings.humidityAccuracy, .two)
        XCTAssertEqual(settings.pressureAccuracy, .two)
        fixture.defaults.set("corrupt", forKey: Constants.temperatureAccuracyKey.rawValue)
        settings = fixture.model.getAppSettings()
        XCTAssertEqual(settings.temperatureAccuracy, .two)
        let noDefaults = WidgetViewModel(defaults: nil, preferredLanguage: { "invalid" }) { [] }
        XCTAssertFalse(noDefaults.isAuthorized())
        XCTAssertFalse(noDefaults.shouldForceRefresh())
        noDefaults.forceRefreshWidget(true)
        XCTAssertFalse(noDefaults.shouldForceRefresh())
        XCTAssertEqual(noDefaults.refreshIntervalMins(), 60)
        XCTAssertEqual(noDefaults.getAppSettings().language, .english)
    }

    func testAllSavedUnitsAndIndependentMeasurementAccuraciesAreRestored() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        for (raw, unit): (Int, UnitTemperature) in [(1, .kelvin), (2, .celsius), (3, .fahrenheit)] {
            fixture.defaults.set(raw, forKey: Constants.temperatureUnitKey.rawValue)
            XCTAssertEqual(fixture.model.getAppSettings().temperatureUnit, unit)
        }
        for (raw, unit): (Int, HumidityUnit) in [(0, .percent), (1, .gm3), (2, .dew), (99, .percent)] {
            fixture.defaults.set(raw, forKey: Constants.humidityUnitKey.rawValue)
            XCTAssertEqual(fixture.model.getAppSettings().humidityUnit, unit)
        }
        for unit: UnitPressure in [.newtonsPerMetersSquared, .hectopascals, .inchesOfMercury, .millimetersOfMercury] {
            fixture.defaults.set(unit.hashValue, forKey: Constants.pressureUnitKey.rawValue)
            XCTAssertEqual(fixture.model.getAppSettings().pressureUnit, unit)
        }
        for (raw, accuracy): (Int, MeasurementAccuracyType) in [(0, .zero), (1, .one), (2, .two), (99, .two)] {
            for key: Constants in [
                .temperatureAccuracyKey, .humidityAccuracyKey, .pressureAccuracyKey, .relativeHumidityAccuracyKey,
                .absoluteHumidityAccuracyKey, .dewPointAccuracyKey, .pmAccuracyKey, .accelerationAccuracyKey,
                .voltageAccuracyKey,
            ] {
                fixture.defaults.set(raw, forKey: key.rawValue)
            }
            let settings = fixture.model.getAppSettings()
            XCTAssertEqual(settings.temperatureAccuracy, accuracy)
            XCTAssertEqual(settings.relativeHumidityAccuracy, accuracy)
            XCTAssertEqual(settings.absoluteHumidityAccuracy, accuracy)
            XCTAssertEqual(settings.dewPointAccuracy, accuracy)
            XCTAssertEqual(settings.pressureAccuracy, accuracy)
            XCTAssertEqual(settings.pmAccuracy, accuracy)
            XCTAssertEqual(settings.accelerationAccuracy, accuracy)
            XCTAssertEqual(settings.voltageAccuracy, accuracy)
        }
        fixture.defaults.set(0, forKey: Constants.relativeHumidityAccuracyKey.rawValue)
        fixture.defaults.set(1, forKey: Constants.absoluteHumidityAccuracyKey.rawValue)
        fixture.defaults.set(2, forKey: Constants.dewPointAccuracyKey.rawValue)
        for (raw, accuracy): (Int, MeasurementAccuracyType) in [(0, .zero), (1, .one), (2, .two)] {
            fixture.defaults.set(raw, forKey: Constants.humidityUnitKey.rawValue)
            XCTAssertEqual(fixture.model.getAppSettings().humidityAccuracy, accuracy)
        }
    }

    func testWidgetLanguageFollowsSavedAppLanguageAndFallback() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        for language: Language in [.english, .finnish, .french, .swedish, .german, .polish] {
            fixture.defaults.set(language.rawValue, forKey: Constants.languageKey.rawValue)
            XCTAssertEqual(fixture.model.getAppSettings().language, language)
            XCTAssertEqual(fixture.model.locale().language.languageCode?.identifier, language.rawValue)
        }
        fixture.defaults.removeObject(forKey: Constants.languageKey.rawValue)
        let model = WidgetViewModel(defaults: fixture.defaults, preferredLanguage: { "sv" }) { [] }
        XCTAssertEqual(model.getAppSettings().language, .swedish)
        fixture.defaults.set("unknown", forKey: Constants.languageKey.rawValue)
        XCTAssertEqual(model.getAppSettings().language, .english)
    }

    func testRefreshPreferencesHandleInvalidIntervalsAndPersistManualRequests() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        XCTAssertEqual(fixture.model.refreshIntervalMins(), 60)
        for interval in [0, -1] {
            fixture.defaults.set(interval, forKey: Constants.widgetRefreshIntervalKey.rawValue)
            XCTAssertEqual(fixture.model.refreshIntervalMins(), 60)
        }
        fixture.defaults.set(15, forKey: Constants.widgetRefreshIntervalKey.rawValue)
        XCTAssertEqual(fixture.model.refreshIntervalMins(), 15)
        XCTAssertFalse(fixture.model.shouldForceRefresh())
        fixture.model.forceRefreshWidget(true)
        XCTAssertTrue(fixture.model.shouldForceRefresh())
        fixture.model.forceRefreshWidget(false)
        XCTAssertFalse(fixture.model.shouldForceRefresh())
    }

    func testMeasurementTimeDistinguishesTodayOlderDataAndMissingData() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let today = fixture.date
        let yesterday = today.addingTimeInterval(-86400)
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        XCTAssertEqual(fixture.model.measurementTime(from: today), formatter.string(from: today))
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        XCTAssertEqual(fixture.model.measurementTime(from: yesterday), formatter.string(from: yesterday))
        XCTAssertEqual(
            fixture.model.measurementTime(from: Optional<Date>.none),
            RuuviLocalization.Cards.UpdatedLabel.NoData.message)
        XCTAssertEqual(
            fixture.model.relativeMeasurementTime(from: .empty()), RuuviLocalization.Cards.UpdatedLabel.NoData.message)
    }
}
