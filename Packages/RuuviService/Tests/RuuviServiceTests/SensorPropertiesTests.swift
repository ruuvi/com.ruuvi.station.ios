import BTKit
import RuuviUser
import Foundation
import XCTest
import UIKit
import RuuviCloud
import RuuviContext
import RuuviCore
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviStorage
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviLocalUserDefaults
    import RuuviPersistenceSQLite
    import RuuviPoolCoordinator
    import RuuviStorageCoordinator
    import RuuviServiceSensorProperties
    import RuuviServiceOwnership
    import RuuviServiceAlert
#endif

final class SensorPropertiesTests: XCTestCase {
    @MainActor func testRemovalCompletesLocallyWhileUnclaimIsSuspended() async throws {
        let fixture = try PropertiesFixture()
        let sensor = fixture.sensor.with(luid: UUID().uuidString.luid)
        _ = try await fixture.pool.create(sensor)
        let gate = AsyncStream<Void>.makeStream()
        defer { gate.continuation.finish() }
        let cloudStarted = expectation(description: "Cloud unclaim started")
        fixture.cloud.onUnclaim = {
            cloudStarted.fulfill()
            for await _ in gate.stream { break }
        }
        let localCompleted = expectation(description: "Local removal completed before cloud response")
        let gatt = StoppedGATT()
        let ownership = fixture.ownership(gatt: gatt)
        let task = Task { @MainActor in
            _ = try await ownership.remove(sensor: sensor, removeCloudHistory: false)
            localCompleted.fulfill()
        }
        await fulfillment(of: [cloudStarted, localCompleted], timeout: 3)
        gate.continuation.finish()
        try await task.value
        XCTAssertEqual(gatt.stopped, sensor.luid?.value)
        let remaining = try await fixture.storage.readAll()
        XCTAssertTrue(remaining.isEmpty)
    }

    @MainActor func testFailedGATTStopPreservesSensorAndRestoresSyncEligibility() async throws {
        let fixture = try PropertiesFixture()
        let sensor = fixture.sensor.with(luid: UUID().uuidString.luid)
        _ = try await fixture.pool.create(sensor)
        let sync = RuuviLocalFactoryUserDefaults().createLocalSyncState()
        sync.setAutoGattSyncSuppressed(false, for: sensor.macId)
        let gatt = StoppedGATT()
        gatt.shouldFail = true
        do {
            _ = try await fixture.ownership(gatt: gatt).remove(sensor: sensor, removeCloudHistory: false)
            XCTFail("Failed cancellation must prevent deletion")
        } catch {
            guard case .macIdIsNil = error else { return XCTFail("Unexpected error: \(error)") }
        }
        let remaining = try await fixture.storage.readAll()
        XCTAssertEqual(remaining.map(\.id), [sensor.id])
        XCTAssertFalse(sync.isAutoGattSyncSuppressed(for: sensor.macId))
    }

    @MainActor func testRenameCommitsLocallyWhileCloudIsSuspended() async throws {
        let fixture = try PropertiesFixture()
        let sensor = fixture.sensor
        _ = try await fixture.pool.create(sensor)
        let gate = AsyncStream<Void>.makeStream()
        defer { gate.continuation.finish() }
        let cloudStarted = expectation(description: "Cloud request started")
        fixture.cloud.onName = { name in
            XCTAssertEqual(name, "Renamed sensor")
            cloudStarted.fulfill()
            for await _ in gate.stream { break }
        }
        let localCompleted = expectation(description: "Local rename completed before cloud response")
        let task = Task { @MainActor in
            let result = try await fixture.service.set(name: "Renamed sensor", for: sensor)
            XCTAssertEqual(result.name, "Renamed sensor")
            localCompleted.fulfill()
        }
        await fulfillment(of: [cloudStarted, localCompleted], timeout: 3)
        gate.continuation.finish()
        try await task.value
        let stored = try await fixture.storage.readOne(sensor.id)
        XCTAssertEqual(stored.name, "Renamed sensor")
        XCTAssertNotNil(stored.lastUpdated)
    }

    @MainActor func testDefaultBackgroundCompletesLocallyWhileCloudIsSuspended() async throws {
        let fixture = try PropertiesFixture()
        _ = try await fixture.pool.create(fixture.sensor)
        let gate = AsyncStream<Void>.makeStream()
        defer { gate.continuation.finish() }
        let cloudStarted = expectation(description: "Cloud image reset started")
        fixture.cloud.onResetImage = {
            cloudStarted.fulfill()
            for await _ in gate.stream { break }
        }
        let localCompleted = expectation(description: "Local background changed before cloud response")
        let task = Task { @MainActor in
            let image = try await fixture.service.setNextDefaultBackground(for: fixture.sensor)
            XCTAssertTrue(image === fixture.images.image)
            localCompleted.fulfill()
        }
        await fulfillment(of: [cloudStarted, localCompleted], timeout: 3)
        gate.continuation.finish()
        try await task.value
        XCTAssertEqual(fixture.images.backgroundChanges, 1)
        let stored = try await fixture.storage.readOne(fixture.sensor.id)
        XCTAssertNotNil(stored.lastUpdated)
    }

    @MainActor func testDefaultBackgroundWithNoIdentityFailsWithoutChangingAnImage() async throws {
        let fixture = try PropertiesFixture()
        do {
            _ = try await fixture.service.setNextDefaultBackground(luid: nil, macId: nil)
            XCTFail("Missing identity must fail")
        } catch {
            guard case .bothLuidAndMacAreNil = error else { return XCTFail("Wrong error: \(error)") }
        }
        XCTAssertEqual(fixture.images.backgroundChanges, 0)
    }
}

@MainActor final class PropertiesFixture {
    let context: SQLiteContext
    let directory: URL
    let pool: RuuviPool
    let storage: RuuviStorage
    let cloud = CloudSpy()
    let images = PropertiesImagesSpy()
    let sensor = RuuviTagSensorStruct(
        version: 5, firmwareVersion: nil, luid: nil,
        macId: "AA:BB:CC:DD:EE:01".mac, serviceUUID: nil, isConnectable: false,
        name: "Original", isClaimed: true, isOwner: true, owner: nil, ownersPlan: nil,
        isCloudSensor: true, canShare: false, sharedTo: [], maxHistoryDays: nil)
    lazy var service = RuuviServiceSensorPropertiesImpl(
        pool: pool, cloud: cloud, coreImage: ImageCropStub(), localImages: images)

    func ownership(gatt: GATTService) -> RuuviServiceOwnershipImpl {
        let local = RuuviLocalFactoryUserDefaults()
        return RuuviServiceOwnershipImpl(
            cloud: cloud, pool: pool, propertiesService: service, localIDs: local.createLocalIDs(),
            localImages: images, storage: storage,
            alertService: RuuviServiceAlertImpl(
                cloud: cloud, localIDs: local.createLocalIDs(), ruuviLocalSettings: local.createLocalSettings()),
            ruuviUser: OwnershipTestUser(), localSyncState: local.createLocalSyncState(),
            settings: local.createLocalSettings(), gattService: gatt)
    }

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("test.sqlite"))
        let persistence = RuuviPersistenceSQLite(context: context)
        let local = RuuviLocalFactoryUserDefaults()
        pool = RuuviPoolFactoryCoordinator().create(
            sqlite: persistence, idPersistence: local.createLocalIDs(), settings: local.createLocalSettings(),
            connectionPersistence: local.createLocalConnections())
        storage = RuuviStorageFactoryCoordinator().create(sqlite: persistence)
    }
    deinit {
        try? context.database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }
}

private struct ImageCropStub: RuuviCoreImage {
    func cropped(image: UIImage, to maxSize: CGSize) -> UIImage { image }
}

private final class OwnershipTestUser: RuuviUser {
    var apiKey: String? { "test-key" }
    var email: String? = "test@example.com"
    var isAuthorized: Bool { true }
    func login(apiKey: String) {}
    func logout() {}
}

private final class StoppedGATT: GATTService {
    var stopped: String?
    var shouldFail = false
    func isSyncingLogs() -> Bool { false }
    func isSyncingLogs(with uuid: String) -> Bool { false }
    // swiftlint:disable:next function_parameter_count
    func syncLogs(
        uuid: String, mac: String?, firmware: Int, from: Date, settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?, timeouts: GATTServiceTimeouts
    )
        async throws(RuuviServiceError) -> Bool
    { false }
    func stopGattSync(for uuid: String) async throws(RuuviServiceError) -> Bool {
        if shouldFail { throw .macIdIsNil }
        stopped = uuid
        return true
    }
}
