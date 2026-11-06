import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class SnapshotAlertSynchronizationTests: XCTestCase {
    func testReloadingPersistedAlertStateClearsOldFiringFlagsAndRestoresActiveMutes() {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let snapshot = fixture.snapshot
        let mute = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 3600)
        let active: [AlertType] = [
            .temperature(lower: 10, upper: 30), .carbonDioxide(lower: 400, upper: 1000), .connection,
        ]
        for type in active {
            fixture.register(type)
            fixture.alerts.mute(type: type, for: fixture.sensor, till: mute)
            snapshot.updateAlertConfig(for: type, config: .init(isActive: true, isFiring: true, mutedTill: nil))
        }
        snapshot.syncAllAlerts(from: fixture.alerts, physicalSensor: fixture.sensor)
        XCTAssertEqual(snapshot.getActiveAlertsCount(), 3)
        XCTAssertEqual(snapshot.getFiringAlertsCount(), 0)
        XCTAssertEqual(snapshot.getMutedAlertsCount(), 3)
        for type in active {
            XCTAssertTrue(snapshot.getAlertConfig(for: type)?.isActive == true)
            XCTAssertEqual(snapshot.getAlertConfig(for: type)?.mutedTill, mute)
        }
        XCTAssertFalse(snapshot.getAlertConfig(for: .cloudConnection(unseenDuration: 900))?.isActive ?? true)
        fixture.alerts.unregister(type: active[0], ruuviTag: fixture.sensor)
        snapshot.syncAllAlerts(from: fixture.alerts, physicalSensor: fixture.sensor)
        XCTAssertEqual(snapshot.getActiveAlertsCount(), 2)
        XCTAssertFalse(snapshot.getAlertConfig(for: active[0])?.isActive ?? true)
        snapshot.removeAlertConfig(for: .connection)
        XCTAssertNil(snapshot.getAlertConfig(for: .connection))
        snapshot.removeAlertConfig(for: MeasurementType.co2)
        XCTAssertFalse(snapshot.hasAnyActiveAlerts())
        snapshot.removeAlertConfig(for: MeasurementType.accelerationX)
    }

    func testLegacyAlertUpdatesHighlightTheMatchingIndicatorAndDisablingClearsTheBadge() {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let snapshot = fixture.snapshot
        let indicator = fixture.indicator(.init(type: .temperature))
        snapshot.updateAlert(for: .temperature, isOn: true, alertState: .firing, mutedTill: nil)
        XCTAssertTrue(snapshot.isIndicatorHighlighted(for: indicator))
        XCTAssertEqual(snapshot.alertBadgeData()?.count, 1)
        snapshot.updateAlert(for: .temperature, isOn: false, alertState: .empty, mutedTill: nil)
        XCTAssertFalse(snapshot.isIndicatorHighlighted(for: indicator))
        XCTAssertNil(snapshot.alertBadgeData())
        snapshot.updateAlert(for: .accelerationX, isOn: true, alertState: .firing, mutedTill: nil)
        XCTAssertNil(snapshot.getAlertConfig(for: MeasurementType.accelerationX))
    }
}
