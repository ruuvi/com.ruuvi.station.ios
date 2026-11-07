import Foundation
import Humidity
import RuuviOntology
import RuuviService
import XCTest
@testable import station

/// Runs the pinned original implementation and migrated implementation with identical inputs and dependencies.
/// This checks measurement behavior, not the original app binary or historical OS/library versions.
@MainActor final class MeasurementBaselineParityTests: XCTestCase {
    func testTemperatureAndPressureMatchTheOriginalAcrossUnitsLanguagesAndPrecisions() {
        let fixture = MeasurementBaselineFixture()
        for language in Language.allCases {
            fixture.settings.language = language
            for accuracy: MeasurementAccuracyType in [.zero, .one, .two] {
                fixture.settings.temperatureAccuracy = accuracy
                fixture.settings.pressureAccuracy = accuracy
                for unit: TemperatureUnit in [.celsius, .fahrenheit, .kelvin] {
                    fixture.settings.temperatureUnit = unit
                    fixture.refreshUnits()
                    for celsius: Double? in [nil, -40, -0.125, 0, 20.125, 85] {
                        let value = celsius.map { Temperature(value: $0, unit: .celsius) }
                        for useSettings in [false, true] {
                            XCTAssertEqual(
                                fixture.current.string(for: value, allowSettings: useSettings),
                                fixture.original.string(for: value, allowSettings: useSettings))
                        }
                        XCTAssertEqual(
                            fixture.current.stringWithoutSign(for: value),
                            fixture.original.stringWithoutSign(for: value))
                        XCTAssertEqual(
                            fixture.current.stringWithoutSign(temperature: celsius),
                            fixture.original.stringWithoutSign(temperature: celsius))
                        if let value {
                            XCTAssertEqual(fixture.current.double(for: value), fixture.original.double(for: value))
                        }
                    }
                }
                for unit: UnitPressure in [
                    .hectopascals, .inchesOfMercury, .millimetersOfMercury, .newtonsPerMetersSquared,
                ] {
                    fixture.settings.pressureUnit = unit
                    fixture.refreshUnits()
                    for hectopascals: Double? in [nil, 300, 999.995, 1000, 1013.25, 1100] {
                        let value = hectopascals.map { Pressure(value: $0, unit: .hectopascals) }
                        for useSettings in [false, true] {
                            XCTAssertEqual(
                                fixture.current.string(for: value, allowSettings: useSettings),
                                fixture.original.string(for: value, allowSettings: useSettings))
                        }
                        XCTAssertEqual(
                            fixture.current.stringWithoutSign(for: value),
                            fixture.original.stringWithoutSign(for: value))
                        XCTAssertEqual(
                            fixture.current.stringWithoutSign(pressure: hectopascals),
                            fixture.original.stringWithoutSign(pressure: hectopascals))
                        if let value {
                            XCTAssertEqual(fixture.current.double(for: value), fixture.original.double(for: value))
                        }
                    }
                }
            }
        }
    }

    func testHumidityConversionsAndConfiguredFormattingMatchTheOriginal() {
        let fixture = MeasurementBaselineFixture()
        for language in Language.allCases {
            fixture.settings.language = language
            for unit: HumidityUnit in [.percent, .gm3, .dew] {
                fixture.settings.humidityUnit = unit
                for accuracy: MeasurementAccuracyType in [.zero, .one, .two] {
                    fixture.settings.relativeHumidityAccuracy = accuracy
                    fixture.settings.absoluteHumidityAccuracy = accuracy
                    fixture.settings.dewPointAccuracy = accuracy
                    for temperatureUnit: TemperatureUnit in [.celsius, .fahrenheit, .kelvin] {
                        fixture.settings.temperatureUnit = temperatureUnit
                        fixture.refreshUnits()
                        for celsius in [-20.0, 0, 20, 40] {
                            let temperature = Temperature(value: celsius, unit: .celsius)
                            for relative in [0.01, 0.5, 0.999, 1] {
                                let humidity = Humidity(relative: relative, temperature: temperature)
                                for decimal in [false, true] {
                                    XCTAssertEqual(
                                        fixture.current.double(
                                            for: humidity, temperature: temperature, isDecimal: decimal),
                                        fixture.original.double(
                                            for: humidity, temperature: temperature, isDecimal: decimal))
                                }
                                XCTAssertEqual(
                                    fixture.current.stringWithoutSign(for: humidity, temperature: temperature),
                                    fixture.original.stringWithoutSign(for: humidity, temperature: temperature))
                                XCTAssertEqual(
                                    fixture.current.string(
                                        for: humidity, temperature: temperature, allowSettings: true),
                                    fixture.original.string(
                                        for: humidity, temperature: temperature, allowSettings: true))
                            }
                        }
                    }
                }
            }
        }
    }

    func testAirQualityThresholdsAndDisplayStringsMatchTheOriginal() {
        let fixture = MeasurementBaselineFixture()
        let carbonDioxide: [Double?] = [nil, 0, 419, 420, 599, 600, 799, 800, 999, 1000, 1349, 1350, 2099, 2100, 5000]
        let particles: [Double?] = [nil, 0, 4.99, 5, 11.99, 12, 29.99, 30, 54.99, 55, 100]
        for co2 in carbonDioxide {
            XCTAssertEqual(fixture.current.co2(for: co2).value, fixture.original.co2(for: co2).value)
            XCTAssertEqual(fixture.current.co2(for: co2).state, fixture.original.co2(for: co2).state)
            for pm25 in particles {
                let current = fixture.current.aqi(for: co2, pm25: pm25)
                let original = fixture.original.aqi(for: co2, pm25: pm25)
                XCTAssertEqual(current.currentScore, original.currentScore)
                XCTAssertEqual(current.maxScore, original.maxScore)
                XCTAssertEqual(current.state, original.state)
                let currentExportScore = fixture.current.aqi(for: co2, and: pm25)
                let originalExportScore = fixture.original.aqi(for: co2, and: pm25)
                if originalExportScore.isNaN {
                    XCTAssertTrue(currentExportScore.isNaN, "Missing inputs retain the original unavailable score")
                } else {
                    XCTAssertEqual(currentExportScore, originalExportScore)
                }
                XCTAssertEqual(fixture.current.pm25(for: pm25).value, fixture.original.pm25(for: pm25).value)
                XCTAssertEqual(fixture.current.pm25(for: pm25).state, fixture.original.pm25(for: pm25).state)
            }
        }
        for value: Double? in [nil, -1, 0, 0.005, 12.345, 49.5, 99.95, 2500] {
            XCTAssertEqual(strings(fixture.current, value: value), strings(fixture.original, value: value))
        }
    }

    func testVoltageAndCalibrationOffsetsKeepTheOriginalUnitsAndRounding() {
        let fixture = MeasurementBaselineFixture()
        for accuracy: MeasurementAccuracyType in [.zero, .one, .two] {
            fixture.settings.voltageAccuracy = accuracy
            for number: Double? in [nil, 0, 1.995, 2.4, 3.12345] {
                let voltage = number.map { Voltage(value: $0, unit: .volts) }
                XCTAssertEqual(fixture.current.string(for: voltage), fixture.original.string(for: voltage))
                XCTAssertEqual(
                    fixture.current.stringWithoutSign(for: voltage), fixture.original.stringWithoutSign(for: voltage))
                if let voltage {
                    XCTAssertEqual(fixture.current.double(for: voltage), fixture.original.double(for: voltage))
                }
            }
        }
        for unit: TemperatureUnit in [.celsius, .fahrenheit, .kelvin] {
            fixture.settings.temperatureUnit = unit
            fixture.refreshUnits()
            for offset in [-2.125, -0.001, 0, 0.125, 5] {
                XCTAssertEqual(
                    fixture.current.temperatureOffsetCorrection(for: offset),
                    fixture.original.temperatureOffsetCorrection(for: offset))
                XCTAssertEqual(
                    fixture.current.temperatureOffsetCorrectionString(for: offset),
                    fixture.original.temperatureOffsetCorrectionString(for: offset))
            }
        }
        for unit: UnitPressure in [.hectopascals, .inchesOfMercury, .millimetersOfMercury, .newtonsPerMetersSquared] {
            fixture.settings.pressureUnit = unit
            fixture.refreshUnits()
            for offset in [-10.125, 0, 12.345] {
                XCTAssertEqual(
                    fixture.current.pressureOffsetCorrection(for: offset),
                    fixture.original.pressureOffsetCorrection(for: offset))
                XCTAssertEqual(
                    fixture.current.pressureOffsetCorrectionString(for: offset),
                    fixture.original.pressureOffsetCorrectionString(for: offset))
            }
        }
    }

    func testExplicitHumidityPrecisionIsTheDocumentedCorrectionToTheOriginal() {
        let fixture = MeasurementBaselineFixture()
        fixture.settings.language = .english
        fixture.settings.humidityUnit = .percent
        fixture.settings.relativeHumidityAccuracy = .zero
        fixture.settings.absoluteHumidityAccuracy = .two
        fixture.refreshUnits()
        let temperature = Temperature(value: 20, unit: .celsius)
        let humidity = Humidity(relative: 0.5, temperature: temperature)
        let oldAbsolute = fixture.original.string(
            for: humidity, temperature: temperature, allowSettings: true, unit: .gm3)
        let correctedAbsolute = fixture.current.string(
            for: humidity, temperature: temperature, allowSettings: true, unit: .gm3)
        XCTAssertNotEqual(correctedAbsolute, oldAbsolute)
        fixture.settings.humidityUnit = .gm3
        fixture.refreshUnits()
        XCTAssertEqual(
            correctedAbsolute,
            fixture.original.string(
                for: humidity, temperature: temperature, allowSettings: true))
        fixture.settings.humidityUnit = .percent
        fixture.refreshUnits()
        fixture.settings.relativeHumidityAccuracy = .two
        let oldRaw = fixture.original.string(
            for: humidity, temperature: temperature, allowSettings: false, unit: .percent)
        let correctedRaw = fixture.current.string(
            for: humidity, temperature: temperature, allowSettings: false, unit: .percent)
        XCTAssertNotEqual(correctedRaw, oldRaw)
        XCTAssertFalse(correctedRaw.contains((Locale.current.decimalSeparator ?? ".") + "00"))
    }

    func testUnrepresentableIntegerReadingsRenderUnavailableInsteadOfCrashing() {
        let service = MeasurementBaselineFixture().current
        for value: Double? in [
            nil, .nan, .infinity, -.infinity, .greatestFiniteMagnitude,
            -.greatestFiniteMagnitude, Double(Int.max), Double(Int.min).nextDown,
        ] {
            XCTAssertEqual(service.co2String(for: value), "-")
            XCTAssertEqual(service.vocString(for: value), "-")
            XCTAssertEqual(service.noxString(for: value), "-")
            XCTAssertEqual(service.soundString(for: value), "-")
            XCTAssertEqual(service.luminosityString(for: value), "-")
        }
    }

    func testUnrepresentablePascalReadingsRenderUnavailableWithoutIntegerConversionTraps() {
        let fixture = MeasurementBaselineFixture()
        fixture.settings.pressureUnit = .newtonsPerMetersSquared
        fixture.refreshUnits()
        for value in [
            Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude,
            -.greatestFiniteMagnitude, Double(Int.max), Double(Int.min).nextDown,
        ] {
            let pressure = Pressure(value: value, unit: .newtonsPerMetersSquared)
            XCTAssertEqual(fixture.current.string(for: pressure, allowSettings: true), "-")
            XCTAssertEqual(fixture.current.string(for: pressure, allowSettings: false), "-")
            XCTAssertEqual(fixture.current.stringWithoutSign(for: pressure), "-")
            XCTAssertEqual(fixture.current.stringWithoutSign(pressure: value), "-")
        }
    }

    private func strings(_ service: RuuviServiceMeasurement, value: Double?) -> [String] {
        [
            service.string(for: value), service.string(from: value), service.aqiString(for: value),
            service.co2String(for: value), service.pm10String(for: value), service.pm25String(for: value),
            service.pm40String(for: value), service.pm100String(for: value), service.vocString(for: value),
            service.noxString(for: value), service.soundString(for: value), service.luminosityString(for: value),
            service.accelerationString(for: value),
        ]
    }
}

@MainActor private final class MeasurementBaselineFixture {
    let settings = AppTestSettings()
    let original: BaselineMeasurementService
    let current: RuuviServiceMeasurementImpl
    init() {
        original = BaselineMeasurementService(settings: settings, emptyValueString: "-", percentString: "%")
        current = RuuviServiceMeasurementImpl(settings: settings, emptyValueString: "-", percentString: "%")
    }
    func refreshUnits() { original.updateUnits(); current.updateUnits() }
}
