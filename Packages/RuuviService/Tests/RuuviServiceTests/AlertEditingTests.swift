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

@MainActor final class AlertEditingTests: XCTestCase {
    func testEveryThresholdAndDescriptionPersistsThroughBothIdentityAPIs() async throws {
        for identity in 0..<3 {
            let fixture = AlertMatrixFixture(identity: identity, cloud: identity == 0)
            defer { fixture.clean() }
            let service = fixture.service
            let sensor = fixture.sensor
            let noNetwork = expectation(description: "Local sensor never uploads")
            noNetwork.isInverted = true
            fixture.cloud.onAlert = { noNetwork.fulfill() }
            for metric in AlertMetric.all {
                let label = metric.type.rawValue
                XCTAssertNil(metric.lowerValue(service, sensor), label)
                XCTAssertNil(metric.upperValue(service, sensor), label)
                XCTAssertNil(metric.description(service, sensor), label)
                service.register(type: metric.type, ruuviTag: sensor)
                metric.setLower(service, metric.lower + 1, sensor)
                metric.setUpper(service, metric.upper + 2, sensor)
                metric.setDescription(service, "Custom 🌿 " + label, sensor)
                XCTAssertEqual(metric.lowerValue(service, sensor), metric.lower + 1, label)
                XCTAssertEqual(metric.upperValue(service, sensor), metric.upper + 2, label)
                XCTAssertEqual(metric.description(service, sensor), "Custom 🌿 " + label, label)
                let reopened = RuuviServiceAlertImpl(
                    cloud: fixture.cloud, localIDs: fixture.ids,
                    ruuviLocalSettings: fixture.settings)
                XCTAssertEqual(metric.lowerValue(reopened, sensor), metric.lower + 1, label)
                XCTAssertEqual(metric.upperValue(reopened, sensor), metric.upper + 2, label)
                for id in [sensor.luid?.value, sensor.macId?.value].compactMap({ $0 }) {
                    XCTAssertEqual(metric.legacyLower(service, id), metric.lower + 1, label)
                    XCTAssertEqual(metric.legacyUpper(service, id), metric.upper + 2, label)
                    XCTAssertEqual(metric.legacyDescription(service, id), "Custom 🌿 " + label, label)
                    XCTAssertTrue(service.isOn(type: metric.type, for: id), label)
                }
                metric.setLower(service, nil, sensor)
                metric.setUpper(service, nil, sensor)
                metric.setDescription(service, nil, sensor)
                XCTAssertNil(metric.lowerValue(service, sensor), label)
                XCTAssertNil(metric.upperValue(service, sensor), label)
                XCTAssertNil(metric.description(service, sensor), label)
            }
            await fulfillment(of: [noNetwork], timeout: 0.05)
        }
    }

    func testEveryCloudAlertSendsCorrectUnitsAndIndependentMutations() async throws {
        for identity in 1...2 {
            let fixture = AlertMatrixFixture(identity: identity, cloud: true)
            defer { fixture.clean() }
            let service = fixture.service
            let sensor = fixture.sensor
            for metric in AlertMetric.all {
                var request = try await write(fixture) { service.register(type: metric.type, ruuviTag: sensor) }
                XCTAssertEqual(request.type, metric.cloudType)
                XCTAssertEqual(request.mac, sensor.macId?.value)
                XCTAssertTrue(request.enabled)
                XCTAssertEqual(try XCTUnwrap(request.min), metric.lower * metric.scale, accuracy: 0.00001)
                XCTAssertEqual(try XCTUnwrap(request.max), metric.upper * metric.scale, accuracy: 0.00001)
                request = try await write(fixture) { metric.setLower(service, metric.lower + 1, sensor) }
                XCTAssertEqual(request.settingType, .lowerBound)
                XCTAssertEqual(try XCTUnwrap(request.min), (metric.lower + 1) * metric.scale, accuracy: 0.00001)
                XCTAssertEqual(try XCTUnwrap(request.max), metric.upper * metric.scale, accuracy: 0.00001)
                request = try await write(fixture) { metric.setUpper(service, metric.upper + 2, sensor) }
                XCTAssertEqual(request.settingType, .upperBound)
                XCTAssertEqual(try XCTUnwrap(request.min), (metric.lower + 1) * metric.scale, accuracy: 0.00001)
                XCTAssertEqual(try XCTUnwrap(request.max), (metric.upper + 2) * metric.scale, accuracy: 0.00001)
                request = try await write(fixture) { metric.setDescription(service, "Alarm 🌿", sensor) }
                XCTAssertEqual(request.settingType, .description)
                XCTAssertEqual(request.description, "Alarm 🌿")
                request = try await write(fixture) { metric.setDescription(service, nil, sensor) }
                XCTAssertNil(request.description)
                request = try await write(fixture) { service.unregister(type: metric.type, ruuviTag: sensor) }
                XCTAssertEqual(request.settingType, .state)
                XCTAssertFalse(request.enabled)
                request = try await write(fixture) { metric.setLower(service, nil, sensor) }
                XCTAssertFalse(request.enabled)
                request = try await write(fixture) { metric.setUpper(service, nil, sensor) }
                XCTAssertFalse(request.enabled)
            }
        }
    }

    func testCombinedIdentityFallsBackToSavedMacAlertWhenLocalIdentifierHasNoValues() {
        let fixture = AlertMatrixFixture()
        defer { fixture.clean() }
        var macOnly = fixture.sensor
        macOnly.luid = nil
        for metric in AlertMetric.all {
            fixture.service.register(type: metric.type, ruuviTag: macOnly)
            metric.setDescription(fixture.service, "MAC stored", macOnly)
            XCTAssertEqual(metric.lowerValue(fixture.service, fixture.sensor), metric.lower, metric.type.rawValue)
            XCTAssertEqual(metric.upperValue(fixture.service, fixture.sensor), metric.upper, metric.type.rawValue)
            XCTAssertEqual(metric.description(fixture.service, fixture.sensor), "MAC stored", metric.type.rawValue)
        }
    }

    func write(_ fixture: AlertMatrixFixture, action: () -> Void) async throws -> CloudSpy.AlertRequest {
        let completed = expectation(description: "Cloud mutation completes")
        let before = fixture.cloud.alerts.count
        fixture.cloud.onAlert = { completed.fulfill() }
        action()
        await fulfillment(of: [completed], timeout: 3)
        fixture.cloud.onAlert = nil
        XCTAssertEqual(fixture.cloud.alerts.count, before + 1)
        return try XCTUnwrap(fixture.cloud.alerts.last)
    }
}
