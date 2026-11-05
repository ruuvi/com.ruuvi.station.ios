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

final class AlertLifecycleTests: XCTestCase {
    @MainActor func testEveryAlertCanRegisterMuteTriggerUnmuteAndRemove() {
        let suite = "AlertLifecycleTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let factory = RuuviLocalFactoryUserDefaults()
        let service = RuuviServiceAlertImpl(
            cloud: CloudSpy(), localIDs: factory.createLocalIDs(), ruuviLocalSettings: factory.createLocalSettings(),
            defaults: defaults)
        for identity in 0..<3 {
            let sensor = makeSensor(identity: identity, cloud: false)
            for type in AlertType.allCases {
                defer { service.remove(type: type, ruuviTag: sensor) }
                XCTAssertFalse(service.isOn(type: type, for: sensor))
                service.register(type: type, ruuviTag: sensor)
                XCTAssertTrue(service.isOn(type: type, for: sensor), type.rawValue)
                XCTAssertTrue(service.hasRegistrations(for: sensor))
                let until = Date(timeIntervalSince1970: 2_000_000_000)
                service.mute(type: type, for: sensor, till: until)
                XCTAssertEqual(service.mutedTill(type: type, for: sensor), until, type.rawValue)
                service.trigger(type: type, trigerred: true, trigerredAt: "2026-01-01T00:00:00Z", for: sensor)
                XCTAssertEqual(service.triggered(for: sensor, of: type), true, type.rawValue)
                XCTAssertEqual(service.triggeredAt(for: sensor, of: type), "2026-01-01T00:00:00Z", type.rawValue)
                service.unmute(type: type, for: sensor)
                XCTAssertNil(service.mutedTill(type: type, for: sensor), type.rawValue)
                service.unregister(type: type, ruuviTag: sensor)
                XCTAssertFalse(service.isOn(type: type, for: sensor), type.rawValue)
                service.remove(type: type, ruuviTag: sensor)
                XCTAssertNil(service.alert(for: sensor, of: type), type.rawValue)
            }
            XCTAssertFalse(service.hasRegistrations(for: sensor))
        }
    }

    @MainActor func testCloudRegistrationConvertsHumidityAndPressureUnits() async throws {
        let suite = "AlertLifecycleTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let factory = RuuviLocalFactoryUserDefaults()
        let cloud = CloudSpy()
        let service = RuuviServiceAlertImpl(
            cloud: cloud, localIDs: factory.createLocalIDs(), ruuviLocalSettings: factory.createLocalSettings(),
            defaults: defaults)
        let sensor = makeSensor(identity: 1, cloud: true)
        let writes = expectation(description: "Converted cloud alert requests")
        writes.expectedFulfillmentCount = 2
        cloud.onAlert = { writes.fulfill() }
        let humidity = AlertType.relativeHumidity(lower: 0.2, upper: 0.8)
        let pressure = AlertType.pressure(lower: 950, upper: 1050)
        defer { service.remove(type: humidity, ruuviTag: sensor); service.remove(type: pressure, ruuviTag: sensor) }
        service.register(type: humidity, ruuviTag: sensor)
        service.register(type: pressure, ruuviTag: sensor)
        await fulfillment(of: [writes], timeout: 3)
        let humidityRequest = try XCTUnwrap(cloud.alerts.first { $0.type == .humidity })
        XCTAssertEqual(humidityRequest.min, 20)
        XCTAssertEqual(humidityRequest.max, 80)
        XCTAssertTrue(humidityRequest.enabled)
        XCTAssertEqual(humidityRequest.mac, sensor.macId?.value)
        let pressureRequest = try XCTUnwrap(cloud.alerts.first { $0.type == .pressure })
        XCTAssertEqual(pressureRequest.min, 95000)
        XCTAssertEqual(pressureRequest.max, 105000)
    }

    private func makeSensor(identity: Int, cloud: Bool) -> RuuviTagSensorStruct {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        let bytes = stride(from: 0, to: 8, by: 2).map { offset -> String in
            let start = suffix.index(suffix.startIndex, offsetBy: offset)
            return String(suffix[start..<suffix.index(start, offsetBy: 2)])
        }
        return RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil,
            luid: identity == 1 ? nil : UUID().uuidString.luid,
            macId: identity == 0 ? nil : ("AA:BB:" + bytes.joined(separator: ":")).mac,
            serviceUUID: nil, isConnectable: false, name: "Alert fixture", isClaimed: cloud,
            isOwner: true, owner: nil, ownersPlan: nil, isCloudSensor: cloud, canShare: false,
            sharedTo: [], maxHistoryDays: nil)
    }
}
