import Foundation
import Future
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviStorage
import RuuviUser

public final class RuuviServiceAuthImpl: RuuviServiceAuth {
    private let ruuviUser: RuuviUser
    private let pool: RuuviPool
    private let storage: RuuviStorage
    private let propertiesService: RuuviServiceSensorProperties
    private let localIDs: RuuviLocalIDs
    private let localSyncState: RuuviLocalSyncState
    private let alertService: RuuviServiceAlert

    public init(
        ruuviUser: RuuviUser,
        pool: RuuviPool,
        storage: RuuviStorage,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs,
        localSyncState: RuuviLocalSyncState,
        alertService: RuuviServiceAlert
    ) {
        self.ruuviUser = ruuviUser
        self.pool = pool
        self.storage = storage
        self.propertiesService = propertiesService
        self.localIDs = localIDs
        self.localSyncState = localSyncState
        self.alertService = alertService
    }

    public func logout() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        ruuviUser.logout()

        storage.readAll()
            .on(success: { [weak self] localSensors in
                guard let sSelf = self else {
                    return
                }

                let sensorsToDelete = localSensors.filter { $0.isClaimed || $0.isCloud }
                guard !sensorsToDelete.isEmpty else {
                    promise.succeed(value: true)
                    sSelf.postNotification()
                    return
                }

                // Collect all individual operations from all sensors
                var allOperations: [Future<Bool, RuuviPoolError>] = []

                for sensor in sensorsToDelete {
                    let deleteSensorOperation = sSelf.pool.delete(sensor)
                    let deleteRecordsOperation = sSelf.pool.deleteAllRecords(sensor.id)
                    let deleteLatestRecordOperation = sSelf.pool.deleteLast(sensor.id)

                    allOperations.append(deleteSensorOperation)
                    allOperations.append(deleteRecordsOperation)
                    allOperations.append(deleteLatestRecordOperation)

                    // Perform synchronous cleanup operations
                    sSelf.propertiesService.removeImage(for: sensor)
                    sSelf.localSyncState.setSyncDate(nil, for: sensor.macId)
                    sSelf.localSyncState.setSyncDate(nil)
                    sSelf.localSyncState.setGattSyncDate(nil, for: sensor.macId)

                    // Remove all alert types for this sensor
                    AlertType.allCases.forEach { type in
                        sSelf.alertService.remove(type: type, ruuviTag: sensor)
                    }
                }

                // Add the global deleteQueuedRequests operation
                allOperations.append(sSelf.pool.deleteQueuedRequests())

                // Wait for all operations to complete
                Future.zip(allOperations)
                    .on(success: { _ in
                        promise.succeed(value: true)
                        sSelf.postNotification()
                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })

            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })

        return promise.future
    }
}

private extension RuuviServiceAuthImpl {
    func deleteSensor(_ sensor: RuuviTagSensor) -> Future<[Bool], RuuviPoolError> {
        let deleteSensorOperation = pool.delete(sensor)
        let deleteRecordsOperation = pool.deleteAllRecords(sensor.id)
        let deleteLatestRecordOperation = pool.deleteLast(sensor.id)

        // Perform synchronous cleanup operations
        propertiesService.removeImage(for: sensor)
        localSyncState.setSyncDate(nil, for: sensor.macId)
        localSyncState.setSyncDate(nil)
        localSyncState.setGattSyncDate(nil, for: sensor.macId)

        // Remove all alert types for this sensor
        AlertType.allCases.forEach { type in
            alertService.remove(type: type, ruuviTag: sensor)
        }

        // Return combined async operations
        return Future.zip([
            deleteSensorOperation,
            deleteRecordsOperation,
            deleteLatestRecordOperation,
        ])
    }

    func postNotification() {
        NotificationCenter
            .default
            .post(name: .RuuviAuthServiceDidLogout, object: self, userInfo: nil)
    }
}
