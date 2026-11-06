import BTKit
import Foundation
import RuuviDaemon
import RuuviDFU
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import XCTest
@testable import station

@MainActor final class FirmwarePersistenceTests: XCTestCase {
    func testSuccessfulFirmwareReadPreservesTheLatestSensorMetadataAndRestoresConnectability() async throws {
        let fixture = try FirmwarePersistenceFixture()
        defer { fixture.cleanup() }
        var latest = fixture.sensor
        latest.name = "Renamed during upgrade"
        latest.isConnectable = false
        latest.firmwareVersion = "1.0.0"
        fixture.measurements.storage.oneSensors = [latest.macId!.value: latest.any]
        fixture.model.storeUpdatedFirmware(latestRelease: fixture.release, currentRelease: .init(version: "3.10.0"))
        await waitForAppState("firmware persisted") {
            fixture.pool.updatedSensors.count == 1 && !fixture.model.isLoading
        }
        let updated = try XCTUnwrap(fixture.pool.updatedSensors.last)
        XCTAssertEqual(updated.name, latest.name)
        XCTAssertEqual(updated.firmwareVersion, "3.10.0")
        XCTAssertEqual(updated.macId?.value, latest.macId?.value)
        XCTAssertTrue(updated.isConnectable)
        XCTAssertEqual(fixture.activity.shown.count, 1)
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
    }

    func testEquivalentFirmwareDoesNotRewriteTheSensorUnlessItNeedsReconnection() async throws {
        let fixture = try FirmwarePersistenceFixture()
        defer { fixture.cleanup() }
        var latest = fixture.sensor
        latest.firmwareVersion = "3.10.0+0"
        latest.isConnectable = true
        fixture.measurements.storage.oneSensors = [latest.macId!.value: latest.any]
        fixture.model.storeUpdatedFirmware(latestRelease: fixture.release, currentRelease: .init(version: "3.10.0"))
        await waitForAppState("unchanged firmware completes") { fixture.activity.dismissals.count == 1 }
        XCTAssertTrue(fixture.pool.updatedSensors.isEmpty)
        latest.isConnectable = false
        fixture.measurements.storage.oneSensors = [latest.macId!.value: latest.any]
        fixture.model.storeUpdatedFirmware(latestRelease: fixture.release, currentRelease: .init(version: "3.10.0"))
        await waitForAppState("reconnect flag persisted") { fixture.pool.updatedSensors.count == 1 }
        XCTAssertTrue(fixture.pool.updatedSensors[0].isConnectable)
        await waitForAppState("reconnect spinner finishes") { !fixture.model.isLoading }
    }

    func testInvalidationClearsTheLatestVersionWithoutShowingAnActivityIndicator() async throws {
        let fixture = try FirmwarePersistenceFixture()
        defer { fixture.cleanup() }
        var latest = fixture.sensor
        latest.name = "Current metadata"
        latest.firmwareVersion = "3.9.0"
        fixture.measurements.storage.oneSensors = [latest.macId!.value: latest.any]
        fixture.model.invalidateStoredFirmwareVersion()
        await waitForAppState("stale version invalidated") { fixture.pool.updatedSensors.count == 1 }
        XCTAssertNil(fixture.pool.updatedSensors[0].firmwareVersion)
        XCTAssertEqual(fixture.pool.updatedSensors[0].name, "Current metadata")
        XCTAssertTrue(fixture.activity.shown.isEmpty)
        XCTAssertTrue(fixture.activity.dismissals.isEmpty)
    }

    func testMissingStoredSensorUsesTheOriginalAndWriteFailureStillDismissesLoading() async throws {
        let fixture = try FirmwarePersistenceFixture()
        defer { fixture.cleanup() }
        fixture.measurements.storage.oneSensors = [:]
        fixture.pool.allowSensorUpdates = false
        fixture.model.storeUpdatedFirmware(latestRelease: fixture.release, currentRelease: .init(version: "3.10.0"))
        await waitForAppState("failed storage finishes") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.pool.updatedSensors.first?.name, fixture.sensor.name)
        XCTAssertEqual(fixture.pool.updatedSensors.first?.firmwareVersion, "3.10.0")
        XCTAssertFalse(fixture.model.isLoading)
    }

    func testCloudOnlySensorCannotStartLocalFirmwarePersistence() async throws {
        let fixture = try FirmwarePersistenceFixture(local: false)
        defer { fixture.cleanup() }
        fixture.model.storeUpdatedFirmware(latestRelease: fixture.release, currentRelease: .init(version: "3.10.0"))
        fixture.model.invalidateStoredFirmwareVersion()
        await flushAppBindings()
        XCTAssertTrue(fixture.measurements.storage.oneReads.isEmpty)
        XCTAssertTrue(fixture.pool.updatedSensors.isEmpty)
        XCTAssertTrue(fixture.activity.shown.isEmpty)
    }
}

@MainActor private final class FirmwarePersistenceFixture {
    let measurements = MeasurementFixture()
    let pool = AppPoolSpy()
    let activity = AccountActivitySpy()
    let release = LatestRelease(version: "3.10.0", assets: [])
    let sensor: RuuviTagSensorStruct
    var model: DFUViewModel!
    init(local: Bool = true) throws {
        var sensor = measurements.sensor
        if !local { sensor.luid = nil }
        self.sensor = sensor
        pool.allowSensorUpdates = true
        let resolver = AppAssembly.shared.assembler.resolver
        model = DFUViewModel(
            interactor: IdleFirmwareInteractor(), foreground: BTKit.foreground,
            idPersistence: try XCTUnwrap(resolver.resolve(RuuviLocalIDs.self)),
            sqiltePersistence: try XCTUnwrap(resolver.resolve(RuuviPersistence.self, name: "sqlite")),
            ruuviTag: sensor, ruuviPool: pool, ruuviStorage: measurements.storage, settings: measurements.settings,
            propertiesDaemon: try XCTUnwrap(resolver.resolve(RuuviTagPropertiesDaemon.self)),
            activityPresenter: activity)
    }
    func cleanup() { model = nil; measurements.cleanup() }
}
