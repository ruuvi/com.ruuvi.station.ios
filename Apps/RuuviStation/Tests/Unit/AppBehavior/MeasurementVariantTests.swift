import Foundation
import Humidity
import RuuviLocal
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class MeasurementVariantTests: XCTestCase {
    func testEveryMeasurementUsesItsOwnValueAndUnit() throws {
        let fixture = MeasurementFixture()
        let resolver = fixture.resolver()
        let reading = fixture.record().measurement
        let expected: [(MeasurementType, Double)] = [
            (.temperature, 20), (.humidity, 50), (.pressure, 1000), (.co2, 800),
            (.pm10, 1), (.pm25, 2.5), (.pm40, 4), (.pm100, 10), (.voc, 100), (.nox, 5),
            (.luminosity, 200), (.soundInstant, 30), (.soundAverage, 25), (.soundPeak, 40),
            (.voltage, 3), (.rssi, -60), (.accelerationX, 0.1), (.accelerationY, -0.2),
            (.accelerationZ, 1), (.measurementSequenceNumber, 42),
        ]
        for (type, value) in expected {
            XCTAssertEqual(
                try XCTUnwrap(
                    resolver.value(
                        for: reading, variant: .init(type: type), sensorSettings: nil
                    )), value, accuracy: 0.0001, "\(type)")
        }
        for type: MeasurementType in [.movementCounter, .txPower] {
            XCTAssertNil(resolver.value(for: reading, variant: .init(type: type), sensorSettings: nil))
        }
        let graphAQI = try XCTUnwrap(
            resolver.value(
                for: reading, variant: .init(type: .aqi), sensorSettings: nil, configuration: .cardsGraph
            ))
        let detailAQI = try XCTUnwrap(resolver.value(for: reading, variant: .init(type: .aqi), sensorSettings: nil))
        XCTAssertGreaterThan(graphAQI, 0)
        XCTAssertLessThanOrEqual(graphAQI, 100)
        XCTAssertEqual(detailAQI, graphAQI.rounded(), accuracy: 0.1)
    }

    func testExplicitUnitsOverridePreferencesAndOffsetsAreAppliedOnce() throws {
        let fixture = MeasurementFixture()
        let resolver = fixture.resolver()
        let reading = fixture.record().measurement
        let offsets = SensorSettingsStruct(
            luid: fixture.sensor.luid, macId: fixture.sensor.macId,
            temperatureOffset: 2, humidityOffset: 0.1, pressureOffset: 10
        )
        fixture.settings.temperatureUnit = .kelvin
        fixture.settings.pressureUnit = .inchesOfMercury
        let values: [(MeasurementDisplayVariant, Double)] = [
            (.init(type: .temperature), 295.15),
            (.init(type: .temperature, temperatureUnit: .fahrenheit), 71.6),
            (.init(type: .temperature, temperatureUnit: .celsius), 22),
            (.init(type: .pressure, pressureUnit: .hectopascals), 1010),
            (.init(type: .pressure, pressureUnit: .millimetersOfMercury), 757.563307),
            (.init(type: .humidity, humidityUnit: .percent), 60),
        ]
        for (variant, expected) in values {
            XCTAssertEqual(
                try XCTUnwrap(resolver.value(for: reading, variant: variant, sensorSettings: offsets)),
                expected, accuracy: 0.02)
        }
        let dewC = try XCTUnwrap(
            resolver.value(
                for: reading, variant: .init(type: .humidity, temperatureUnit: .celsius, humidityUnit: .dew),
                sensorSettings: offsets
            ))
        XCTAssertEqual(dewC, 13.9, accuracy: 0.3)
        let dewF = try XCTUnwrap(
            resolver.value(
                for: reading, variant: .init(type: .humidity, temperatureUnit: .fahrenheit, humidityUnit: .dew),
                sensorSettings: offsets
            ))
        XCTAssertEqual(dewF, dewC * 1.8 + 32, accuracy: 0.001)
        fixture.settings.humidityUnit = .gm3
        let absolute = try XCTUnwrap(
            resolver.value(for: reading, variant: .init(type: .humidity), sensorSettings: offsets))
        let graph = try XCTUnwrap(
            resolver.value(
                for: reading, variant: .init(type: .humidity), sensorSettings: offsets, configuration: .cardsGraph
            ))
        XCTAssertGreaterThan(absolute, graph, "Details apply the temperature calibration when deriving humidity")
        XCTAssertEqual(graph, 10.37, accuracy: 0.1)
    }

    func testMissingMeasurementsAndUninitializedGasSensorsStayAbsent() {
        let fixture = MeasurementFixture()
        let resolver = fixture.resolver()
        var reading = fixture.record().measurement
        reading.temperature = nil
        reading.humidity = nil
        reading.pressure = nil
        reading.voltage = .init(value: 0, unit: .volts)
        reading.voc = 0
        reading.nox = 0
        reading.co2 = nil
        reading.pm25 = nil
        reading.acceleration = nil
        reading.rssi = nil
        for type: MeasurementType in [
            .temperature, .humidity, .pressure, .voltage, .voc, .nox,
            .aqi, .co2, .pm25, .accelerationX, .accelerationY, .accelerationZ, .rssi,
        ] {
            XCTAssertNil(resolver.value(for: reading, variant: .init(type: type), sensorSettings: nil), "\(type)")
            XCTAssertNil(
                resolver.value(
                    for: reading, variant: .init(type: type), sensorSettings: nil, configuration: .cardsGraph
                ), "\(type)")
        }
    }

    func testAlertBoundsForAllMetricsHideOnlyTheDisabledBoundary() throws {
        let fixture = MeasurementFixture()
        let resolver = fixture.resolver()
        let cases: [(MeasurementDisplayVariant, Double, Double)] = [
            (.init(type: .temperature), -40, 85), (.init(type: .humidity, humidityUnit: .percent), 0, 100),
            (.init(type: .humidity, humidityUnit: .gm3), 0, 50),
            (.init(type: .humidity, humidityUnit: .dew), -40, 85), (.init(type: .pressure), 500, 1155),
            (.init(type: .aqi), 0, 100), (.init(type: .co2), 350, 2500),
            (.init(type: .pm10), 0, 250), (.init(type: .pm25), 0, 250),
            (.init(type: .pm40), 0, 250), (.init(type: .pm100), 0, 250),
            (.init(type: .voc), 1, 500), (.init(type: .nox), 1, 500),
            (.init(type: .luminosity), 0, 144284), (.init(type: .soundInstant), 0, 127),
            (.init(type: .soundAverage), 0, 127), (.init(type: .soundPeak), 0, 127),
            (.init(type: .voltage), 1.8, 3.6), (.init(type: .rssi), -105, 0),
        ]
        for (variant, lower, upper) in cases {
            let disabled = resolver.alertBounds(
                for: variant, sensor: fixture.sensor.any, alertConfig: config(lower, upper))
            XCTAssertNil(disabled.lower, "\(variant)")
            XCTAssertNil(disabled.upper, "\(variant)")
            let active = resolver.alertBounds(
                for: variant, sensor: fixture.sensor.any, alertConfig: config(lower + 0.1, upper - 0.1)
            )
            XCTAssertEqual(try XCTUnwrap(active.lower), lower + 0.1, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(active.upper), upper - 0.1, accuracy: 0.001)
            XCTAssertNil(resolver.alertBounds(for: variant, sensor: nil, alertConfig: config(lower, upper)).lower)
            XCTAssertNil(resolver.alertBounds(for: variant, sensor: fixture.sensor.any, alertConfig: .inactive).upper)
        }
        let nonAlert = resolver.alertBounds(for: .init(type: .accelerationX), sensor: fixture.sensor.any)
        XCTAssertNil(nonAlert.lower)
        XCTAssertNil(nonAlert.upper)
    }

    func testBoundsRespectCustomLimitsUnitConversionsAndPersistedAlertFallback() throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let resolver = fixture.resolver()
        for (type, flag) in [(MeasurementType.temperature, "temp"), (.co2, "co2"), (.pm25, "pm")] {
            if flag == "temp" { fixture.settings.setShowCustomTempAlertBound(true, for: fixture.sensor.id) }
            if flag == "co2" { fixture.settings.setShowCustomCO2AlertBound(true, for: fixture.sensor.id) }
            if flag == "pm" { fixture.settings.setShowCustomPMAlertBound(true, for: fixture.sensor.id) }
            let bounds: (Double, Double) = flag == "temp" ? (-55, 150) : flag == "co2" ? (0, 40000) : (0, 1000)
            let hidden = resolver.alertBounds(
                for: .init(type: type), sensor: fixture.sensor.any,
                alertConfig: config(bounds.0, bounds.1))
            XCTAssertNil(hidden.lower)
            XCTAssertNil(hidden.upper)
        }
        let celsius = AlertType.temperature(lower: 10, upper: 30)
        fixture.register(celsius)
        fixture.register(.relativeHumidity(lower: 0.2, upper: 0.8))
        fixture.register(.humidity(lower: .init(value: 3, unit: .absolute), upper: .init(value: 12, unit: .absolute)))
        fixture.register(.dewPoint(lower: 5, upper: 15))
        fixture.register(.pressure(lower: 900, upper: 1100))
        let temperature = resolver.alertBounds(
            for: .init(type: .temperature, temperatureUnit: .fahrenheit),
            sensor: fixture.sensor.any)
        XCTAssertEqual(try XCTUnwrap(temperature.lower), 50, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(temperature.upper), 86, accuracy: 0.001)
        for (unit, lower, upper) in [(HumidityUnit.percent, 20.0, 80.0), (.gm3, 3, 12), (.dew, 5, 15)] {
            let bounds = resolver.alertBounds(
                for: .init(type: .humidity, humidityUnit: unit), sensor: fixture.sensor.any)
            XCTAssertEqual(try XCTUnwrap(bounds.lower), lower, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(bounds.upper), upper, accuracy: 0.001)
        }
        let dewF = resolver.alertBounds(
            for: .init(type: .humidity, temperatureUnit: .fahrenheit, humidityUnit: .dew),
            sensor: fixture.sensor.any, alertConfig: config(5, 15)
        )
        XCTAssertEqual(try XCTUnwrap(dewF.lower), 41, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(dewF.upper), 59, accuracy: 0.001)
        let pressure = resolver.alertBounds(
            for: .init(type: .pressure, pressureUnit: .millimetersOfMercury),
            sensor: fixture.sensor.any)
        XCTAssertEqual(try XCTUnwrap(pressure.lower), 675.055, accuracy: 0.02)
        XCTAssertEqual(try XCTUnwrap(pressure.upper), 825.067, accuracy: 0.02)
        fixture.alerts.remove(type: celsius, ruuviTag: fixture.sensor)
        XCTAssertNil(resolver.alertBounds(for: .init(type: .temperature), sensor: fixture.sensor.any).lower)
    }

    private func config(_ lower: Double, _ upper: Double) -> RuuviTagCardSnapshotAlertConfig {
        .init(isActive: true, isFiring: false, mutedTill: nil, lowerBound: lower, upperBound: upper)
    }
}
