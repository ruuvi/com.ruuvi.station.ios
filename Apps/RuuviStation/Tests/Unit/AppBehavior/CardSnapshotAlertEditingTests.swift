import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class CardSnapshotAlertEditingTests: XCTestCase {
    func testMeasurementAlertPartialEditsPreserveFiringStateAndUneditedSettings() {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let snapshot = fixture.snapshot
        let type = AlertType.temperature(lower: 0, upper: 20)
        let mute = Date().addingTimeInterval(3600)
        XCTAssertNil(snapshot.getAlertSettings(for: MeasurementType.temperature))
        snapshot.updateAlertMutedTill(for: MeasurementType.temperature, mutedTill: mute)
        snapshot.updateAlertDescription(for: MeasurementType.temperature, description: "Ignored")
        snapshot.updateAlertBounds(for: MeasurementType.temperature, lowerBound: -10)
        XCTAssertNil(snapshot.getAlertSettings(for: MeasurementType.temperature))
        snapshot.updateAlertConfig(
            for: type,
            config: .init(
                type: .temperature, alertType: type,
                isActive: true, isFiring: true, mutedTill: nil, lowerBound: 0, upperBound: 20, description: "Original"))
        snapshot.updateAlertSettings(
            for: MeasurementType.temperature,
            settings: .init(isOn: true, mutedTill: mute, lowerBound: -5, upperBound: 25, description: "Edited"))
        snapshot.updateAlertBounds(for: MeasurementType.temperature, lowerBound: -10)
        snapshot.updateAlertDescription(for: MeasurementType.temperature, description: "Low temperature")
        var saved = snapshot.getAlertSettings(for: MeasurementType.temperature)
        XCTAssertEqual(saved?.lowerBound, -10)
        XCTAssertEqual(saved?.upperBound, 25)
        XCTAssertEqual(saved?.description, "Low temperature")
        XCTAssertEqual(saved?.mutedTill, mute)
        XCTAssertTrue(snapshot.getAlertConfig(for: type)?.isFiring == true)
        snapshot.updateAlertMutedTill(for: MeasurementType.temperature, mutedTill: nil)
        snapshot.updateAlertBounds(for: MeasurementType.temperature, upperBound: 30)
        saved = snapshot.getAlertSettings(for: MeasurementType.temperature)
        XCTAssertNil(saved?.mutedTill)
        XCTAssertEqual(saved?.lowerBound, -10)
        XCTAssertEqual(saved?.upperBound, 30)
        snapshot.updateAlertSettings(for: MeasurementType.accelerationX, settings: .init(isOn: true))
        XCTAssertNil(snapshot.getAlertSettings(for: MeasurementType.accelerationX))
    }

    func testNonMeasurementAlertEditsPreserveItsDelayAndOtherAlertSettings() {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let snapshot = fixture.snapshot
        let type = AlertType.cloudConnection(unseenDuration: 900)
        let mute = Date().addingTimeInterval(3600)
        XCTAssertNil(snapshot.getAlertSettings(for: type))
        snapshot.updateAlertMutedTill(for: type, mutedTill: mute)
        snapshot.updateAlertDescription(for: type, description: "Ignored")
        snapshot.updateAlertBounds(for: type, lowerBound: 2)
        XCTAssertNil(snapshot.getAlertSettings(for: type))
        snapshot.updateAlertSettings(
            for: type,
            settings: .init(
                isOn: true, mutedTill: mute,
                lowerBound: 1, upperBound: 2, description: "Offline", unseenDuration: 1200))
        snapshot.updateAlertDescription(for: type, description: "No cloud data")
        snapshot.updateAlertBounds(for: type, lowerBound: 0)
        var saved = snapshot.getAlertSettings(for: type)
        XCTAssertEqual(saved?.unseenDuration, 1200)
        XCTAssertEqual(saved?.description, "No cloud data")
        XCTAssertEqual(saved?.upperBound, 2)
        XCTAssertEqual(saved?.mutedTill, mute)
        snapshot.updateAlertMutedTill(for: type, mutedTill: nil)
        snapshot.updateAlertBounds(for: type, upperBound: 3)
        saved = snapshot.getAlertSettings(for: type)
        XCTAssertNil(saved?.mutedTill)
        XCTAssertEqual(saved?.lowerBound, 0)
        XCTAssertEqual(saved?.upperBound, 3)
        XCTAssertEqual(saved?.unseenDuration, 1200)
    }

    func testAlertBadgeAndSummaryPrioritizeFiringAndCountOnlyActiveUnexpiredMutes() {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let snapshot = fixture.snapshot
        XCTAssertFalse(snapshot.hasAnyActiveAlerts())
        XCTAssertFalse(snapshot.hasAnyFiringAlerts())
        XCTAssertNil(snapshot.alertBadgeData())
        XCTAssertEqual(snapshot.getAlertSummary(), "Alerts: 0 active")
        let temperature = AlertType.temperature(lower: 0, upper: 20)
        let pressure = AlertType.pressure(lower: 900, upper: 1100)
        snapshot.updateAlertSettings(
            for: temperature, settings: .init(isOn: true, mutedTill: Date().addingTimeInterval(3600)))
        snapshot.updateAlertSettings(
            for: pressure, settings: .init(isOn: false, mutedTill: Date().addingTimeInterval(3600)))
        snapshot.updateAlertSettings(
            for: .connection, settings: .init(isOn: true, mutedTill: Date().addingTimeInterval(3600)))
        snapshot.updateAlertSettings(
            for: .cloudConnection(unseenDuration: 900),
            settings: .init(isOn: true, mutedTill: Date().addingTimeInterval(-1)))
        XCTAssertTrue(snapshot.hasAnyActiveAlerts())
        XCTAssertEqual(snapshot.getActiveAlertsCount(), 3)
        XCTAssertEqual(snapshot.getMutedAlertsCount(), 2)
        XCTAssertEqual(snapshot.alertBadgeData()?.count, 3)
        XCTAssertEqual(snapshot.alertBadgeData()?.isTriggered, false)
        snapshot.updateAlertConfig(
            for: temperature,
            config: .init(
                type: .temperature, alertType: temperature,
                isActive: true, isFiring: true, mutedTill: nil))
        XCTAssertTrue(snapshot.hasAnyFiringAlerts())
        XCTAssertEqual(snapshot.getFiringAlertsCount(), 1)
        XCTAssertEqual(snapshot.getMutedAlertsCount(), 1)
        XCTAssertEqual(snapshot.alertBadgeData()?.count, 1)
        XCTAssertEqual(snapshot.alertBadgeData()?.isTriggered, true)
        XCTAssertEqual(snapshot.getAlertSummary(), "Alerts: 3 active, 1 firing, 1 muted")
    }
}
