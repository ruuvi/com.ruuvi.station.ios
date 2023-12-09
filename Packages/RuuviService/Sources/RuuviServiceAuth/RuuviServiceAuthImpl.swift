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
                guard let sSelf = self else { return }
                guard localSensors.count != 0
                else {
                    promise.succeed(value: true)
                    return
                }
                localSensors.filter { $0.isClaimed || $0.isCloud }.forEach { sensor in
                    let deleteSensorOperation = sSelf.pool.delete(sensor)
                    let deleteRecordsOperation = sSelf.pool.deleteAllRecords(sensor.id)
                    let deleteLatestRecordOperation = sSelf.pool.deleteLast(sensor.id)
                    let deleteQueuedRequestsOperation = sSelf.pool.deleteQueuedRequests()
                    let cleanUpOperation = sSelf.pool.cleanupDBSpace()
                    sSelf.propertiesService.removeImage(for: sensor)
                    sSelf.localIDs.clear(sensor: sensor)
                    sSelf.localSyncState.setSyncDate(nil, for: sensor.macId)
                    sSelf.localSyncState.setSyncDate(nil)
                    sSelf.localSyncState.setGattSyncDate(nil, for: sensor.macId)
                    AlertType.allCases.forEach { type in
                        sSelf.alertService.remove(type: type, ruuviTag: sensor)
                    }

                    Future.zip([
                        deleteSensorOperation,
                        deleteRecordsOperation,
                        deleteLatestRecordOperation,
                        deleteQueuedRequestsOperation,
                        cleanUpOperation,
                    ])
                    .on(success: { _ in
                        promise.succeed(value: true)
                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })
                }
            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })

        return promise.future
    }
}
