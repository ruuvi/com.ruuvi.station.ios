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

@MainActor final class AlertSyncTests: XCTestCase {
    func testCloudAlertsRoundTripEveryMeasurementAndDescriptionWithoutEchoingToCloud() async throws {
        for identity in 1...2 {
            let fixture = AlertMatrixFixture(identity: identity)
            defer { fixture.clean() }
            for metric in AlertMetric.all {
                let cloud = CloudAlertFixture(
                    type: metric.cloudType, min: metric.lower * metric.scale,
                    max: metric.upper * metric.scale)
                fixture.service.sync(cloudAlerts: [
                    .init(sensor: fixture.sensor.macId?.value, alerts: [cloud]) as CloudSensorAlertsFixture
                ])
                XCTAssertEqual(metric.lowerValue(fixture.service, fixture.sensor), metric.lower, metric.type.rawValue)
                XCTAssertEqual(metric.upperValue(fixture.service, fixture.sensor), metric.upper, metric.type.rawValue)
                XCTAssertEqual(
                    metric.description(fixture.service, fixture.sensor), cloud.description, metric.type.rawValue)
                XCTAssertTrue(fixture.service.isOn(type: metric.type, for: fixture.sensor), metric.type.rawValue)
                XCTAssertEqual(fixture.service.triggered(for: fixture.sensor, of: metric.type), true)
                XCTAssertEqual(fixture.service.triggeredAt(for: fixture.sensor, of: metric.type), cloud.triggeredAt)
                var disabled = cloud
                disabled.enabled = false
                fixture.service.sync(cloudAlerts: [
                    CloudSensorAlertsFixture(sensor: fixture.sensor.macId?.value, alerts: [disabled])
                ])
                XCTAssertFalse(fixture.service.isOn(type: metric.type, for: fixture.sensor), metric.type.rawValue)
            }
            XCTAssertTrue(fixture.cloud.alerts.isEmpty)
        }
    }

    func testStaleCloudAlertsQueueTheNewerLocalStateForEveryMeasurement() async throws {
        let fixture = AlertMatrixFixture()
        defer { fixture.clean() }
        let completed = expectation(description: "All newer local alerts are queued")
        completed.expectedFulfillmentCount = AlertMetric.all.count
        fixture.cloud.onAlert = { completed.fulfill() }
        for metric in AlertMetric.all {
            fixture.service.register(type: metric.type, ruuviTag: fixture.sensor)
            metric.setDescription(fixture.service, "Local description", fixture.sensor)
            let stale = CloudAlertFixture(
                type: metric.cloudType, enabled: false,
                min: 0, max: 0, lastUpdated: Date(timeIntervalSince1970: 1))
            fixture.service.sync(cloudAlerts: [
                CloudSensorAlertsFixture(sensor: fixture.sensor.macId?.value, alerts: [stale])
            ])
            XCTAssertEqual(metric.lowerValue(fixture.service, fixture.sensor), metric.lower, metric.type.rawValue)
            XCTAssertEqual(metric.description(fixture.service, fixture.sensor), "Local description")
        }
        await fulfillment(of: [completed], timeout: 3)
        fixture.cloud.onAlert = nil
        XCTAssertEqual(fixture.cloud.alerts.count, AlertMetric.all.count)
        for metric in AlertMetric.all {
            let request = try XCTUnwrap(fixture.cloud.alerts.first { $0.type == metric.cloudType })
            XCTAssertTrue(request.enabled)
            XCTAssertEqual(request.settingType, .state)
            XCTAssertEqual(try XCTUnwrap(request.min), metric.lower * metric.scale, accuracy: 0.00001)
            XCTAssertEqual(try XCTUnwrap(request.max), metric.upper * metric.scale, accuracy: 0.00001)
            XCTAssertEqual(request.description, "Local description")
        }
    }

    func testEqualCloudTimestampDoesNotOverwriteOrQueueLocalAlert() async {
        let fixture = AlertMatrixFixture()
        defer { fixture.clean() }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let persistence = fixture.persistence
        for metric in AlertMetric.all {
            fixture.service.register(type: metric.type, ruuviTag: fixture.sensor)
            for id in [fixture.sensor.luid?.value, fixture.sensor.macId?.value].compactMap({ $0 }) {
                persistence.setUpdatedAt(date, for: id, of: metric.type)
            }
            let same = CloudAlertFixture(type: metric.cloudType, enabled: false, min: 0, max: 1, lastUpdated: date)
            fixture.service.sync(cloudAlerts: [
                CloudSensorAlertsFixture(sensor: fixture.sensor.macId?.value, alerts: [same])
            ])
            XCTAssertTrue(fixture.service.isOn(type: metric.type, for: fixture.sensor))
            XCTAssertEqual(metric.lowerValue(fixture.service, fixture.sensor), metric.lower)
        }
        XCTAssertTrue(fixture.cloud.alerts.isEmpty)
    }

    func testIncompleteCloudAlertsCannotEraseExistingConfiguration() {
        let fixture = AlertMatrixFixture()
        defer { fixture.clean() }
        for metric in AlertMetric.all {
            fixture.service.register(type: metric.type, ruuviTag: fixture.sensor)
            let bad = CloudAlertFixture(type: metric.cloudType, min: nil, max: nil)
            fixture.service.sync(cloudAlerts: [
                CloudSensorAlertsFixture(sensor: fixture.sensor.macId?.value, alerts: [bad])
            ])
            XCTAssertEqual(metric.lowerValue(fixture.service, fixture.sensor), metric.lower)
        }
        fixture.service.sync(cloudAlerts: [
            CloudSensorAlertsFixture(sensor: nil, alerts: nil),
            CloudSensorAlertsFixture(sensor: fixture.sensor.macId?.value, alerts: [CloudAlertFixture(type: nil)]),
        ])
        XCTAssertTrue(fixture.cloud.alerts.isEmpty)
    }
}
