import RuuviLocal
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class SensorDataMetadataTests: XCTestCase {
    func testOwnershipCapabilitiesAndSubscriptionLimitsRefreshWithoutReplacingTheSnapshot() async throws {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        var sensor = fixture.sensor("Office", cloud: true)
        sensor.ownersPlan = "Basic"
        fixture.pool.subscriptions[sensor.id] = AppSubscription(macId: sensor.macId?.value, maxSharesPerSensor: 5)
        await fixture.start([sensor])
        let snapshot = try XCTUnwrap(fixture.service.getSnapshot(for: sensor.id))
        await waitForAppState("subscription loaded") { snapshot.ownership.maxShareCount == 5 }
        XCTAssertFalse(snapshot.ownership.isOwnersPlanProPlus)
        XCTAssertFalse(snapshot.capabilities.isCloudConnectionAlertsAvailable)
        sensor.ownersPlan = "BUSINESS"
        sensor.owner = "OWNER@Example.com"
        sensor.isOwner = false
        sensor.canShare = true
        sensor.isConnectable = false
        sensor.sharedTo = ["a@example.com"]
        sensor.sharedToPending = ["b@example.com"]
        fixture.send(.update(sensor.any))
        await waitForAppState("new ownership metadata") { snapshot.ownership.ownersPlan == "BUSINESS" }
        XCTAssertTrue(snapshot === fixture.service.getSnapshot(for: sensor.id))
        XCTAssertEqual(snapshot.ownership.ownerName, "owner@example.com")
        XCTAssertEqual(snapshot.ownership.sharedTo, sensor.sharedTo)
        XCTAssertEqual(snapshot.ownership.sharedToPending, sensor.sharedToPending)
        XCTAssertTrue(snapshot.ownership.isOwnersPlanProPlus)
        XCTAssertTrue(snapshot.capabilities.isCloudConnectionAlertsAvailable)
        XCTAssertFalse(snapshot.connectionData.isConnectable)
        fixture.pool.subscriptions[sensor.id] = AppSubscription(macId: sensor.macId?.value, maxSharesPerSensor: 12)
        fixture.service.refreshSubscriptionDataForSnapshots()
        await waitForAppState("new share limit") { snapshot.ownership.maxShareCount == 12 }
        fixture.pool.subscriptionFailure = .ruuviPersistence(.failedToFindRuuviTag)
        fixture.service.refreshSubscriptionDataForSnapshots()
        await flushAppBindings()
        XCTAssertEqual(snapshot.ownership.maxShareCount, 12)
        fixture.pool.subscriptionFailure = nil
        fixture.pool.subscriptions.removeValue(forKey: sensor.id)
        fixture.service.refreshSubscriptionDataForSnapshots()
        await waitForAppState("removed subscription") { snapshot.ownership.maxShareCount == nil }
        fixture.measurements.settings.showSwitchStatusLabel = false
        sensor.ownersPlan = "free"
        fixture.send(.update(sensor.any))
        await waitForAppState("free plan") { !snapshot.ownership.isOwnersPlanProPlus }
        XCTAssertFalse(snapshot.capabilities.isCloudConnectionAlertsAvailable)
        XCTAssertTrue(snapshot.capabilities.hideSwitchStatusLabel)
    }

    func testGlobalUnitChangesReuseSnapshotsAndRebuildTheDisplayedMeasurement() async throws {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.sensor(version: 5)
        fixture.measurements.storage.latestOverride = fixture.measurements.record()
        await fixture.start([sensor])
        let snapshot = try XCTUnwrap(fixture.service.getSnapshot(for: sensor.id))
        await waitForAppState("initial reading") { snapshot.latestRawRecord != nil }
        let previousCount = fixture.delegate.lists.count
        var measurement = fixture.measurements.measurement
        measurement.units = .init(
            temperatureUnit: .fahrenheit, humidityUnit: .percent, pressureUnit: .hectopascals)
        await waitForAppState("units rebuilt") { fixture.delegate.lists.count > previousCount }
        XCTAssertTrue(snapshot === fixture.service.getSnapshot(for: sensor.id))
        let temperature = snapshot.displayData.indicatorGrid?.indicators.first { $0.variant.type == .temperature }
        XCTAssertEqual(temperature?.unit, TemperatureUnit.fahrenheit.symbol)
        XCTAssertEqual(
            temperature?.value,
            fixture.measurements.measurement.stringWithoutSign(for: Temperature(value: 20, unit: .celsius)))
        XCTAssertTrue(temperature?.value.contains("68") == true)
        XCTAssertEqual(snapshot.latestRawRecord?.temperature?.value, 20)
    }

    func testRenamingUsesThePropertiesServiceAndMissingSnapshotsDoNotTriggerWrites() async throws {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.sensor()
        await fixture.start([sensor])
        let snapshot = try XCTUnwrap(fixture.service.getSnapshot(for: sensor.id))
        fixture.service.snapshotSensorNameDidChange(to: "Kitchen", for: snapshot)
        await waitForAppState("name saved") { fixture.properties.names.count == 1 }
        XCTAssertEqual(fixture.properties.names.first?.0, sensor.id)
        XCTAssertEqual(fixture.properties.names.first?.1, "Kitchen")
        fixture.properties.failure = .failedToParseNetworkResponse
        fixture.service.snapshotSensorNameDidChange(to: "Failing rename", for: snapshot)
        await waitForAppState("failed name save attempted") { fixture.properties.names.count == 2 }
        XCTAssertEqual(snapshot.displayData.name, sensor.name)
        fixture.service.snapshotSensorNameDidChange(to: "Ignored", for: fixture.measurements.snapshot)
        await flushAppBindings()
        XCTAssertEqual(fixture.properties.names.count, 2)
    }
}
