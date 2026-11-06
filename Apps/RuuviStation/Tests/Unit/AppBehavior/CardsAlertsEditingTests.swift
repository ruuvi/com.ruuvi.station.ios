import Foundation
import Humidity
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class CardsAlertsEditingTests: XCTestCase {
    func testMeasurementAlertEditsPersistThroughTheCoordinatorAndUnchangedTogglesPreserveMute() async throws {
        let fixture = CardsAlertsFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let service = fixture.services.data.measurements.alerts
        let sensor = fixture.sensor
        for metric in CardAlertMetric.all {
            fixture.snapshot.updateAlertConfig(
                for: metric.type,
                config: .init(
                    type: metric.type.toMeasurementType(),
                    alertType: metric.type, isActive: false, isFiring: false, mutedTill: nil))
            fixture.presenter.viewDidChangeAlertState(for: metric.type, isOn: true)
            fixture.presenter.viewDidChangeAlertLowerBound(for: metric.type, lower: CGFloat(metric.lower))
            fixture.presenter.viewDidChangeAlertUpperBound(for: metric.type, upper: CGFloat(metric.upper))
            fixture.presenter.viewDidChangeAlertDescription(
                for: metric.type, description: "Alarm " + metric.type.rawValue)
            await waitForAppState("alert page stored " + metric.type.rawValue) {
                guard let lower = metric.readLower(service, sensor), let upper = metric.readUpper(service, sensor)
                else { return false }
                return abs(lower - metric.lower * metric.scale) < 0.001
                    && abs(upper - metric.upper * metric.scale) < 0.001
            }
            XCTAssertTrue(service.isOn(type: metric.type, for: sensor))
            XCTAssertEqual(metric.readDescription(service, sensor), "Alarm " + metric.type.rawValue)
            let muted = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 3600)
            service.mute(type: metric.type, for: sensor, till: muted)
            fixture.presenter.viewDidChangeAlertState(for: metric.type, isOn: true)
            XCTAssertEqual(service.mutedTill(type: metric.type, for: sensor), muted)
            fixture.presenter.viewDidChangeAlertState(for: metric.type, isOn: false)
            XCTAssertFalse(service.isOn(type: metric.type, for: sensor))
            fixture.presenter.viewDidChangeAlertDescription(for: metric.type, description: nil)
            XCTAssertNil(metric.readDescription(service, sensor))
        }
    }

    func testDisplayedTemperatureDewPointAndPressureEditsUseCanonicalStorageUnits() async throws {
        let fixture = CardsAlertsFixture()
        defer { fixture.cleanup() }
        var measurement = fixture.services.data.measurements.measurement
        measurement.units = .init(temperatureUnit: .fahrenheit, humidityUnit: .dew, pressureUnit: .inchesOfMercury)
        try await fixture.start()
        let service = fixture.services.data.measurements.alerts
        let temperature = AlertType.temperature(lower: 0, upper: 100)
        let dew = AlertType.dewPoint(lower: 0, upper: 100)
        fixture.presenter.viewDidChangeAlertLowerBound(for: temperature, lower: 32)
        fixture.presenter.viewDidChangeAlertUpperBound(for: temperature, upper: 77)
        fixture.presenter.viewDidChangeAlertLowerBound(for: dew, lower: 50)
        fixture.presenter.viewDidChangeAlertUpperBound(for: dew, upper: 68)
        fixture.presenter.viewDidChangeAlertLowerBound(
            for: .pressure(lower: 0, upper: 1100),
            lower: CGFloat(
                Measurement(value: 1000, unit: UnitPressure.hectopascals).converted(to: .inchesOfMercury).value))
        await waitForAppState("alert page unit conversions") {
            abs((service.lowerPressure(for: fixture.sensor) ?? 0) - 1000) < 0.001
        }
        XCTAssertEqual(service.lowerCelsius(for: fixture.sensor) ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(service.upperCelsius(for: fixture.sensor) ?? -1, 25, accuracy: 0.001)
        XCTAssertEqual(service.lowerDewPoint(for: fixture.sensor) ?? -1, 10, accuracy: 0.001)
        XCTAssertEqual(service.upperDewPoint(for: fixture.sensor) ?? -1, 20, accuracy: 0.001)
    }

    func testDisablingMovementClearsHysteresisAndInvalidCloudDelaysDoNotOverwriteTheStoredValue() async throws {
        let fixture = CardsAlertsFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let movement = AlertType.movement(last: 0)
        let service = fixture.services.data.measurements.alerts
        fixture.presenter.viewDidChangeAlertState(for: movement, isOn: true)
        XCTAssertEqual(service.movementCounter(for: fixture.sensor), 12)
        let clearedBeforeDisabling = fixture.services.notifier.clearedMovement.count
        fixture.presenter.viewDidChangeAlertState(for: movement, isOn: false)
        XCTAssertGreaterThan(fixture.services.notifier.clearedMovement.count, clearedBeforeDisabling)
        XCTAssertEqual(fixture.services.notifier.clearedMovement.last, fixture.sensor.luid!.value)
        fixture.presenter.viewDidChangeCloudConnectionAlertUnseenDuration(duration: 1200)
        await waitForAppState("valid cloud delay") {
            service.cloudConnectionUnseenDuration(for: fixture.sensor) == 1200
        }
        fixture.presenter.viewDidChangeCloudConnectionAlertUnseenDuration(duration: 119)
        fixture.presenter.viewDidChangeCloudConnectionAlertUnseenDuration(duration: 1200)
        XCTAssertEqual(service.cloudConnectionUnseenDuration(for: fixture.sensor), 1200)
    }
}
