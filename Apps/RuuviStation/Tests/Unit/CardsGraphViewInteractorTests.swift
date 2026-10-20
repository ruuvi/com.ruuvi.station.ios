@testable import station
import BTKit
import Future
import RuuviOntology
import RuuviService
import XCTest

final class CardsGraphViewInteractorTests: XCTestCase {
    func testSyncStateBeforeSensorConfigurationIsIdle() {
        let interactor = CardsGraphViewInteractor()

        XCTAssertFalse(interactor.isSyncingRecords(for: nil))
    }

    func testQueuedSyncStateBeforeSensorConfigurationIsIdle() {
        let interactor = CardsGraphViewInteractor()

        XCTAssertFalse(interactor.isSyncingRecordsQueued(for: nil))
    }

    func testSyncProgressBeforeSensorConfigurationIsEmpty() {
        let interactor = CardsGraphViewInteractor()

        XCTAssertNil(interactor.currentSyncProgress(for: nil))
    }

    func testSyncStateUsesRequestedSensorBeforeInteractorConfiguration() {
        let service = GraphGATTServiceStub()
        service.activeUUIDs = ["sensor-a"]
        let interactor = CardsGraphViewInteractor()
        interactor.gattService = service

        XCTAssertTrue(interactor.isSyncingRecords(for: "sensor-a".luid))
        XCTAssertFalse(interactor.isSyncingRecords(for: "sensor-b".luid))
    }

    func testQueuedStateUsesRequestedSensorBeforeInteractorConfiguration() {
        let service = GraphGATTServiceStub()
        service.queuedUUIDs = ["sensor-a"]
        let interactor = CardsGraphViewInteractor()
        interactor.gattService = service

        XCTAssertTrue(interactor.isSyncingRecordsQueued(for: "sensor-a".luid))
        XCTAssertFalse(interactor.isSyncingRecordsQueued(for: "sensor-b".luid))
    }

    func testProgressUsesRequestedSensorBeforeInteractorConfiguration() {
        let service = GraphGATTServiceStub()
        service.progressByUUID = ["sensor-a": .reading(42)]
        let interactor = CardsGraphViewInteractor()
        interactor.gattService = service

        guard case .reading(42)? = interactor.currentSyncProgress(for: "sensor-a".luid) else {
            return XCTFail("Expected the requested sensor's progress")
        }
        XCTAssertNil(interactor.currentSyncProgress(for: "sensor-b".luid))
    }

    func testAnySyncDetectsOperationsWithoutPresenterNotifications() {
        let service = GraphGATTServiceStub()
        service.activeUUIDs = ["sensor-b"]
        let interactor = CardsGraphViewInteractor()
        interactor.gattService = service

        XCTAssertFalse(interactor.isSyncingRecords(for: "sensor-a".luid))
        XCTAssertTrue(interactor.isSyncingAnyRecords())
        service.activeUUIDs = []
        XCTAssertFalse(interactor.isSyncingAnyRecords())
        service.queuedUUIDs = ["sensor-b"]
        XCTAssertTrue(interactor.isSyncingAnyRecords())
    }
}

private final class GraphGATTServiceStub: GATTService {
    var activeUUIDs = Set<String>()
    var queuedUUIDs = Set<String>()
    var progressByUUID: [String: BTServiceProgress] = [:]

    func isSyncingLogs() -> Bool {
        !activeUUIDs.isEmpty || !queuedUUIDs.isEmpty
    }

    func isSyncingLogs(with uuid: String) -> Bool {
        activeUUIDs.contains(uuid) || queuedUUIDs.contains(uuid)
    }

    func isSyncingLogsQueued(with uuid: String) -> Bool {
        queuedUUIDs.contains(uuid)
    }

    func syncProgress(with uuid: String) -> BTServiceProgress? {
        progressByUUID[uuid]
    }

    // swiftlint:disable:next function_parameter_count
    func syncLogs(
        uuid _: String,
        mac _: String?,
        firmware _: Int,
        from _: Date,
        settings _: SensorSettings?,
        progress _: ((BTServiceProgress) -> Void)?,
        timeouts _: GATTServiceTimeouts
    ) -> Future<Bool, RuuviServiceError> {
        XCTFail("Querying sync state must not start a download")
        return Future(value: false)
    }

    func stopGattSync(for _: String) -> Future<Bool, RuuviServiceError> {
        XCTFail("Querying sync state must not stop a download")
        return Future(value: false)
    }
}
