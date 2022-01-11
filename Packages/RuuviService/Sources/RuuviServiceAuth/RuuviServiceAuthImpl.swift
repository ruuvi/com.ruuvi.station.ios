import Foundation
import Future
import RuuviUser
import RuuviStorage
import RuuviPool
import RuuviLocal

public final class RuuviServiceAuthImpl: RuuviServiceAuth {
    private let ruuviUser: RuuviUser
    private let pool: RuuviPool
    private let storage: RuuviStorage
    private let propertiesService: RuuviServiceSensorProperties
    private let localIDs: RuuviLocalIDs
    private let localSyncState: RuuviLocalSyncState

    public init(
        ruuviUser: RuuviUser,
        pool: RuuviPool,
        storage: RuuviStorage,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs,
        localSyncState: RuuviLocalSyncState
    ) {
        self.ruuviUser = ruuviUser
        self.pool = pool
        self.storage = storage
        self.propertiesService = propertiesService
        self.localIDs = localIDs
        self.localSyncState = localSyncState
    }

    public func logout() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        ruuviUser.logout()
        storage.readAll()
            .on(success: { [weak self] localSensors in
                guard let sSelf = self else { return }
                localSensors.filter({ $0.isCloud }).forEach { sensor in
                    let deleteSensorOperation = sSelf.pool.delete(sensor)
                    let deleteRecordsOperation = sSelf.pool.deleteAllRecords(sensor.id)
                    sSelf.propertiesService.removeImage(for: sensor)
                    sSelf.localIDs.clear(sensor: sensor)
                    sSelf.localSyncState.setSyncDate(nil, for: sensor.macId)
                    Future.zip([deleteSensorOperation, deleteRecordsOperation])
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
