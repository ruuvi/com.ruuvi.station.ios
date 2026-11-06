import Foundation
import Humidity
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class MeasurementFormattingTests: XCTestCase {
    func testHumidityConversionsUsePercentAbsoluteAndDewPointUnits() throws {
        let settings = AppTestSettings()
        let service = RuuviServiceMeasurementImpl(settings: settings, emptyValueString: "-", percentString: "%")
        let temperature = Temperature(value: 20, unit: .celsius)
        let humidity = Humidity(relative: 0.5, temperature: temperature)
        for (unit, expected): (HumidityUnit, Double) in [
            (.percent, 50), (.gm3, 8.65), (.dew, 9.26),
        ] {
            service.units = .init(temperatureUnit: .celsius, humidityUnit: unit, pressureUnit: .hectopascals)
            XCTAssertEqual(
                try XCTUnwrap(service.double(for: humidity, temperature: temperature, isDecimal: false)),
                expected, accuracy: 0.1)
            let text = service.stringWithoutSign(for: humidity, temperature: temperature)
            XCTAssertEqual(try number(text), expected, accuracy: 0.1)
            for useSettings in [true, false] {
                XCTAssertFalse(
                    service.string(for: humidity, temperature: temperature, allowSettings: useSettings).isEmpty)
            }
        }
        service.units = .init(temperatureUnit: .celsius, humidityUnit: .percent, pressureUnit: .hectopascals)
        XCTAssertEqual(service.double(for: humidity, temperature: temperature, isDecimal: true), 0.5)
        settings.temperatureUnit = .fahrenheit
        service.units = .init(temperatureUnit: .fahrenheit, humidityUnit: .dew, pressureUnit: .hectopascals)
        XCTAssertEqual(
            try XCTUnwrap(service.double(for: humidity, temperature: temperature, isDecimal: false)), 48.67,
            accuracy: 0.2)
        XCTAssertTrue(service.string(for: humidity, temperature: temperature, allowSettings: true).contains("F"))
    }

    func testMissingAndImpossibleHumidityCannotRenderAValue() {
        let settings = AppTestSettings()
        let service = RuuviServiceMeasurementImpl(settings: settings, emptyValueString: "-", percentString: "%")
        let temperature = Temperature(value: 20, unit: .celsius)
        XCTAssertEqual(service.stringWithoutSign(for: nil as Humidity?, temperature: temperature), "-")
        XCTAssertEqual(service.string(for: nil as Humidity?, temperature: temperature, allowSettings: true), "-")
        service.units = .init(temperatureUnit: .celsius, humidityUnit: .dew, pressureUnit: .hectopascals)
        let invalid = Humidity(relative: .nan, temperature: temperature)
        XCTAssertNil(service.double(for: invalid, temperature: temperature, isDecimal: false))
        XCTAssertEqual(service.stringWithoutSign(for: invalid, temperature: temperature), "-")
        XCTAssertEqual(service.string(for: invalid, temperature: temperature, allowSettings: false), "-")
        for value in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(service.stringWithoutSign(humidity: value), "-")
            XCTAssertEqual(service.aqiString(for: value), "-")
        }
    }

    func testExplicitHumidityUnitUsesItsOwnPrecisionAndUnformattedModeDoesNotForceDecimals() {
        let settings = AppTestSettings()
        settings.humidityUnit = .percent
        settings.relativeHumidityAccuracy = .zero
        settings.absoluteHumidityAccuracy = .two
        let service = RuuviServiceMeasurementImpl(settings: settings, emptyValueString: "-", percentString: "%")
        let temperature = Temperature(value: 20, unit: .celsius)
        let humidity = Humidity(relative: 0.5, temperature: temperature)
        let decimal = Locale.current.decimalSeparator ?? "."
        let absolute = service.string(for: humidity, temperature: temperature, allowSettings: true, unit: .gm3)
        XCTAssertTrue(absolute.contains(decimal), "Absolute humidity must use its own two-decimal precision")
        settings.relativeHumidityAccuracy = .two
        let raw = service.string(for: humidity, temperature: temperature, allowSettings: false, unit: .percent)
        XCTAssertFalse(raw.contains(decimal + "00"), "Formatting without settings must avoid forced trailing decimals")
    }

    func testPressureTemperatureAndVoltageUseConfiguredUnitsAndRounding() throws {
        let settings = AppTestSettings()
        let service = RuuviServiceMeasurementImpl(settings: settings, emptyValueString: "-", percentString: "%")
        service.units = .init(
            temperatureUnit: .fahrenheit, humidityUnit: .percent, pressureUnit: .newtonsPerMetersSquared)
        XCTAssertEqual(service.double(for: Temperature(value: 0, unit: .celsius)), 32)
        XCTAssertEqual(service.stringWithoutSign(for: Pressure(value: 1000.125, unit: .hectopascals)), "100013")
        XCTAssertEqual(service.stringWithoutSign(pressure: 1000.5), "1001")
        service.units = .init(temperatureUnit: .kelvin, humidityUnit: .percent, pressureUnit: .hectopascals)
        XCTAssertEqual(service.double(for: Temperature(value: 0, unit: .celsius)), 273.15)
        XCTAssertEqual(
            try number(service.stringWithoutSign(for: Pressure(value: 1000.125, unit: .hectopascals))), 1000.13,
            accuracy: 0.001)
        XCTAssertEqual(service.stringWithoutSign(for: nil as Pressure?), "-")
        XCTAssertEqual(service.stringWithoutSign(for: nil as Voltage?), "-")
        XCTAssertEqual(service.double(for: Voltage(value: 3000, unit: .millivolts)), 3)
    }

    func testAirQualityFormattingAndThresholdEdgesKeepTheirClassification() {
        let service = RuuviServiceMeasurementImpl(
            settings: AppTestSettings(), emptyValueString: "-", percentString: "%")
        XCTAssertEqual(service.aqiString(for: 49.5), "50")
        XCTAssertEqual(service.aqiString(for: nil), "-")
        XCTAssertEqual(service.co2(for: nil).value, 0)
        XCTAssertEqual(service.pm25(for: nil).value, 0)
        for (value, state): (Double, MeasurementQualityState) in [
            (-1, .excellent(-1)), (419, .excellent(419)), (600, .good(600)), (800, .fair(800)),
            (1350, .poor(1350)), (2100, .veryPoor(2100)),
        ] { XCTAssertEqual(service.co2(for: value).state, state) }
        for (value, state): (Double, MeasurementQualityState) in [
            (-1, .excellent(-1)), (4.9, .excellent(4.9)), (5, .good(5)), (12, .fair(12)),
            (30, .poor(30)), (55, .veryPoor(55)),
        ] { XCTAssertEqual(service.pm25(for: value).state, state) }
    }

    private func number(_ value: String) throws -> Double {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        return try XCTUnwrap(formatter.number(from: value)).doubleValue
    }
}
