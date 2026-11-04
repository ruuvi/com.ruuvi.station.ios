import Foundation
import XCTest
import RuuviCloud
import RuuviLocal
import RuuviOntology
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviLocalUserDefaults
    @testable import RuuviServiceAlert
#endif

@MainActor final class SpecialAlertTests: XCTestCase {
    func testMovementConnectionAndOfflineSettingsPersistForEveryIdentity() {
        for identity in 0..<3 {
            let fixture = AlertMatrixFixture(identity: identity)
            defer { fixture.clean() }
            let service = fixture.service
            let sensor = fixture.sensor
            XCTAssertFalse(service.hasRegistrations(for: sensor))
            service.register(type: .connection, ruuviTag: sensor)
            service.setConnection(description: "Bluetooth disconnected", for: sensor)
            XCTAssertEqual(service.connectionDescription(for: sensor), "Bluetooth disconnected")
            service.register(type: .movement(last: 1), ruuviTag: sensor)
            service.setMovement(counter: 42, for: sensor)
            service.setMovement(description: "Door moved", ruuviTag: sensor)
            XCTAssertEqual(service.movementCounter(for: sensor), 42)
            XCTAssertEqual(service.movementDescription(for: sensor), "Door moved")
            service.register(type: .cloudConnection(unseenDuration: 1), ruuviTag: sensor)
            service.setCloudConnection(description: "Gateway offline", ruuviTag: sensor)
            XCTAssertEqual(service.cloudConnectionUnseenDuration(for: sensor), 900)
            XCTAssertEqual(service.cloudConnectionDescription(for: sensor), "Gateway offline")
            for (input, expected): (Double, Double) in [(-1, 900), (119, 900), (120, 120), (3600, 3600)] {
                service.setCloudConnection(unseenDuration: input, ruuviTag: sensor)
                XCTAssertEqual(service.cloudConnectionUnseenDuration(for: sensor), expected)
            }
            let until = Date(timeIntervalSince1970: 2_000_000_000)
            service.mute(type: .connection, for: sensor, till: until)
            for id in [sensor.luid?.value, sensor.macId?.value].compactMap({ $0 }) {
                XCTAssertTrue(service.hasRegistrations(for: id))
                XCTAssertEqual(service.mutedTill(type: .connection, for: id), until)
                XCTAssertEqual(service.connectionDescription(for: id), "Bluetooth disconnected")
                XCTAssertEqual(service.movementDescription(for: id), "Door moved")
                XCTAssertEqual(service.movementCounter(for: id), 42)
                service.setMovement(counter: 43, for: id)
                XCTAssertEqual(service.movementCounter(for: id), 43)
            }
            service.unmute(type: .connection, for: sensor)
            service.setMovement(counter: nil, for: sensor)
            service.setMovement(description: nil, ruuviTag: sensor)
            service.setConnection(description: nil, for: sensor)
            service.setCloudConnection(description: nil, ruuviTag: sensor)
            service.setCloudConnection(unseenDuration: nil, ruuviTag: sensor)
            XCTAssertNil(service.movementCounter(for: sensor))
            XCTAssertNil(service.movementDescription(for: sensor))
            XCTAssertNil(service.connectionDescription(for: sensor))
            XCTAssertNil(service.cloudConnectionDescription(for: sensor))
            XCTAssertNil(service.cloudConnectionUnseenDuration(for: sensor))
        }
    }

    func testCloudMovementAndOfflineMutationsUseCounterAndSeconds() async throws {
        let fixture = AlertMatrixFixture(cloud: true)
        defer { fixture.clean() }
        let service = fixture.service
        let sensor = fixture.sensor
        // Bluetooth connection alerts have no cloud counterpart.
        service.register(type: .connection, ruuviTag: sensor)
        service.unregister(type: .connection, ruuviTag: sensor)
        XCTAssertTrue(fixture.cloud.alerts.isEmpty)
        var result = try await write(fixture) { service.register(type: .movement(last: 42), ruuviTag: sensor) }
        XCTAssertEqual(result.type, .movement)
        XCTAssertEqual(result.counter, 42)
        XCTAssertNil(result.min)
        XCTAssertNil(result.max)
        XCTAssertTrue(result.enabled)
        result = try await write(fixture) { service.setMovement(description: "Moved", ruuviTag: sensor) }
        XCTAssertEqual(result.settingType, .description)
        XCTAssertEqual(result.description, "Moved")
        result = try await write(fixture) { service.unregister(type: .movement(last: 42), ruuviTag: sensor) }
        XCTAssertFalse(result.enabled)
        result = try await write(fixture) {
            service.register(type: .cloudConnection(unseenDuration: 1), ruuviTag: sensor)
        }
        XCTAssertEqual(result.type, .offline)
        XCTAssertEqual(result.max, 900)
        XCTAssertEqual(result.delay, 0)
        result = try await write(fixture) { service.setCloudConnection(unseenDuration: 120, ruuviTag: sensor) }
        XCTAssertEqual(result.settingType, .delay)
        XCTAssertEqual(result.max, 120)
        result = try await write(fixture) { service.setCloudConnection(description: "Offline", ruuviTag: sensor) }
        XCTAssertEqual(result.settingType, .description)
        XCTAssertEqual(result.description, "Offline")
        XCTAssertEqual(result.max, 120)
        result = try await write(fixture) {
            service.unregister(type: .cloudConnection(unseenDuration: 120), ruuviTag: sensor)
        }
        XCTAssertFalse(result.enabled)
        result = try await write(fixture) { service.setCloudConnection(unseenDuration: nil, ruuviTag: sensor) }
        XCTAssertNil(result.max)
    }

    func testCloudMovementAndOfflineSyncAndConflictResolution() async throws {
        for identity in 1...2 {
            let fixture = AlertMatrixFixture(identity: identity)
            defer { fixture.clean() }
            let service = fixture.service
            let sensor = fixture.sensor
            service.sync(cloudAlerts: [
                CloudSensorAlertsFixture(
                    sensor: sensor.macId?.value,
                    alerts: [
                        CloudAlertFixture(type: .movement, counter: 18),
                        CloudAlertFixture(type: .offline, max: 60),
                    ])
            ])
            XCTAssertEqual(service.movementCounter(for: sensor), 18)
            XCTAssertEqual(service.movementDescription(for: sensor), "Cloud description")
            XCTAssertEqual(service.cloudConnectionUnseenDuration(for: sensor), 900)
            XCTAssertEqual(service.cloudConnectionDescription(for: sensor), "Cloud description")
            service.sync(cloudAlerts: [
                CloudSensorAlertsFixture(
                    sensor: sensor.macId?.value,
                    alerts: [
                        CloudAlertFixture(type: .movement, counter: nil), CloudAlertFixture(type: .offline, max: nil),
                    ])
            ])
            XCTAssertEqual(service.movementCounter(for: sensor), 18)
            XCTAssertEqual(service.cloudConnectionUnseenDuration(for: sensor), 900)
            service.setMovement(description: "Local move", ruuviTag: sensor)
            service.setCloudConnection(description: "Local offline", ruuviTag: sensor)
            struct ExpectedRequest {
                let type: RuuviCloudAlertType
                let counter: Int?
                let max: Double?
                let description: String
            }
            for expected in [
                ExpectedRequest(type: .movement, counter: 18, max: nil, description: "Local move"),
                ExpectedRequest(type: .offline, counter: nil, max: 900, description: "Local offline"),
            ] {
                let result = try await write(fixture) {
                    service.sync(cloudAlerts: [
                        CloudSensorAlertsFixture(
                            sensor: sensor.macId?.value,
                            alerts: [
                                CloudAlertFixture(
                                    type: expected.type, max: 300, counter: 1,
                                    lastUpdated: Date(timeIntervalSince1970: 1))
                            ])
                    ])
                }
                XCTAssertEqual(result.type, expected.type)
                XCTAssertEqual(result.counter, expected.counter)
                XCTAssertEqual(result.max, expected.max)
                XCTAssertEqual(result.description, expected.description)
            }
        }
    }

    func testCloudExtendedBoundsEnableTheCorrespondingEditingRanges() {
        let fixture = AlertMatrixFixture()
        defer { fixture.clean() }
        fixture.service.sync(cloudAlerts: [
            CloudSensorAlertsFixture(
                sensor: fixture.sensor.macId?.value,
                alerts: [
                    CloudAlertFixture(type: .temperature, min: -100, max: 200),
                    CloudAlertFixture(type: .co2, min: 0, max: 40_000),
                    CloudAlertFixture(type: .pm25, min: 0, max: 2000),
                ])
        ])
        XCTAssertTrue(fixture.settings.showCustomTempAlertBound(for: fixture.sensor.id))
        XCTAssertTrue(fixture.settings.showCustomCO2AlertBound(for: fixture.sensor.id))
        XCTAssertTrue(fixture.settings.showCustomPMAlertBound(for: fixture.sensor.id))
    }

    private func write(_ fixture: AlertMatrixFixture, action: () -> Void) async throws -> CloudSpy.AlertRequest {
        let done = expectation(description: "Cloud alert saved")
        let count = fixture.cloud.alerts.count
        fixture.cloud.onAlert = { done.fulfill() }
        action()
        await fulfillment(of: [done], timeout: 3)
        fixture.cloud.onAlert = nil
        XCTAssertEqual(fixture.cloud.alerts.count, count + 1)
        return try XCTUnwrap(fixture.cloud.alerts.last)
    }
}
