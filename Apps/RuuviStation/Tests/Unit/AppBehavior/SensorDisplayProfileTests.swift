import Foundation
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class SensorDisplayProfileTests: XCTestCase {
    func testAlertVariantsIncludePreferredTemperaturePressureAndRelativeHumidityWithoutDuplicates() async throws {
        let fixture = SensorDataFixture()
        let sensor = fixture.sensor()
        defer {
            RuuviTagDataService.clearMeasurementDisplayOverride(for: sensor.id)
            fixture.cleanup()
        }
        // Indicators can display alternative units, while alert editing still needs
        // the selected temperature/pressure units and relative humidity.
        let profile = MeasurementDisplayProfile(entries: [
            .init(.temperature, temperatureUnit: .celsius, contexts: .indicator),
            .init(.pressure, pressureUnit: .inchesOfMercury, contexts: .indicator),
            .init(.humidity, humidityUnit: .dew, contexts: .indicator),
            .init(.co2),
        ])
        RuuviTagDataService.setMeasurementDisplayOverride(profile, for: sensor.id)
        await fixture.start([sensor])
        let snapshot = try XCTUnwrap(fixture.service.getSnapshot(for: sensor.id))
        for (temperature, expected): (UnitTemperature, TemperatureUnit) in [
            (.celsius, .celsius), (.fahrenheit, .fahrenheit), (.kelvin, .kelvin),
        ] {
            var measurement = fixture.measurements.measurement
            measurement.units = .init(
                temperatureUnit: temperature, humidityUnit: .gm3, pressureUnit: .millimetersOfMercury)
            let expectedVariants: [MeasurementDisplayVariant] = [
                .init(type: .temperature, temperatureUnit: expected), .init(type: .co2),
                .init(type: .pressure, pressureUnit: .millimetersOfMercury),
                .init(type: .humidity, humidityUnit: .percent),
            ]
            XCTAssertEqual(
                RuuviTagDataService.alertMeasurementVariants(for: sensor, measurementService: measurement),
                expectedVariants)
            XCTAssertEqual(
                RuuviTagDataService.alertMeasurementVariants(for: snapshot, measurementService: measurement),
                expectedVariants)
        }
        RuuviTagDataService.setMeasurementDisplayOverride(
            .init(entries: [
                .init(.temperature, temperatureUnit: .celsius), .init(.humidity, humidityUnit: .percent),
                .init(.pressure, pressureUnit: .hectopascals),
            ]), for: sensor.id)
        RuuviTagDataService.setPreferredUnits(
            .init(
                temperatureUnit: .celsius, humidityUnit: .percent, pressureUnit: .hectopascals))
        let variants = RuuviTagDataService.alertMeasurementVariants(for: sensor, measurementService: nil)
        XCTAssertEqual(variants.count, 3)
        XCTAssertEqual(Set(variants).count, 3)
    }

    func testCustomOrderCanAddSupportedVariantsToAnOverrideAndIgnoreInvalidOrDuplicateCodes() throws {
        let fixture = SensorDataFixture()
        let sensor = fixture.sensor()
        defer {
            RuuviTagDataService.clearMeasurementDisplayOverride(for: sensor.id)
            fixture.cleanup()
        }
        RuuviTagDataService.setMeasurementDisplayOverride(
            .init(entries: [.init(.co2)]), for: sensor.id)
        let temperature = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit)
        let code = try XCTUnwrap(RuuviTagDataService.measurementCode(for: temperature))
        RuuviTagDataService.setMeasurementDisplayPreference(
            .init(defaultDisplayOrder: false, displayOrderCodes: [code, "unknown", code]), for: sensor.id)
        let custom = RuuviTagDataService.measurementDisplayProfile(for: sensor)
        XCTAssertEqual(custom.orderedVisibleVariants, [temperature])
        XCTAssertTrue(custom.entries[0].supports(.graph))
        RuuviTagDataService.clearMeasurementDisplayPreference(for: sensor.id)
        XCTAssertEqual(
            RuuviTagDataService.measurementDisplayProfile(for: sensor).orderedVisibleTypes, [.co2])
        RuuviTagDataService.clearMeasurementDisplayOverride(for: sensor.id)
        let restored = RuuviTagDataService.measurementDisplayProfile(for: sensor)
        XCTAssertTrue(restored.orderedVisibleTypes.contains(.aqi))
        XCTAssertTrue(restored.orderedVisibleTypes.contains(.co2))
        XCTAssertGreaterThan(restored.entries.count, 10)
    }

    func testStoredOrderingKeepsEachCardAssociatedWithItsSensor() async {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let first = fixture.sensor("Kitchen")
        let second = fixture.sensor("Bedroom")
        await fixture.start([first, second])
        XCTAssertEqual(fixture.service.getSensor(for: first.id)?.id, first.id)
        XCTAssertEqual(fixture.service.getSensor(for: second.id)?.id, second.id)
        XCTAssertNil(fixture.service.getSensor(for: "missing"))
        fixture.measurements.settings.dashboardSensorOrder = [first.id, second.id]
        fixture.service.reorderSnapshots()
        XCTAssertEqual(fixture.service.getAllSnapshots().map(\.id), [first.id, second.id])
        let air = RuuviTagDataService.defaultMeasurementDisplayProfile()
        XCTAssertTrue(air.entries.contains { $0.type == .co2 })
    }
}
