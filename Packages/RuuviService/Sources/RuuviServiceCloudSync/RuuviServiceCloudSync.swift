import Foundation
import Future
import RuuviOntology
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal

final class RuuviServiceCloudSyncImpl: RuuviServiceCloudSync {
    private let ruuviStorage: RuuviStorage
    private let ruuviCloud: RuuviCloud
    private let ruuviPool: RuuviPool
    private let ruuviLocalSettings: RuuviLocalSettings
    private var ruuviLocalSyncState: RuuviLocalSyncState

    init(
        ruuviStorage: RuuviStorage,
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        ruuviLocalSettings: RuuviLocalSettings,
        ruuviLocalSyncState: RuuviLocalSyncState
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviCloud = ruuviCloud
        self.ruuviPool = ruuviPool
        self.ruuviLocalSettings = ruuviLocalSettings
        self.ruuviLocalSyncState = ruuviLocalSyncState
    }

    @discardableResult
    func sync() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()
        var updatedSensors = Set<AnyRuuviTagSensor>()
        ruuviStorage.readAll().on(success: { [weak self] localSensors in
            guard let sSelf = self else { return }
            sSelf.ruuviCloud.loadSensors().on(success: { cloudSensors in
                localSensors.forEach({ localSensor in
                    if let cloudSensor = cloudSensors.first(where: {$0.id == localSensor.id }) {
                        sSelf.ruuviPool.update(localSensor.with(cloudSensor: cloudSensor))
                        updatedSensors.insert(localSensor)
                    } else {
                        let unclaimed = localSensor.unclaimed()
                        if unclaimed.any != localSensor {
                            sSelf.ruuviPool.update(unclaimed)
                            updatedSensors.insert(localSensor)
                        }
                    }
                })
                cloudSensors.filter { cloudSensor in
                    !localSensors.contains(where: { $0.id == cloudSensor.id })
                }.forEach { newCloudSensor in
                    let newLocalSensor = newCloudSensor.ruuviTagSensor
                    sSelf.ruuviPool.create(newLocalSensor)
                    updatedSensors.insert(newLocalSensor.any)
                }
                promise.succeed(value: updatedSensors)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })
        return promise.future
    }

    @discardableResult
    func sync(sensor: RuuviTagSensor) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()
        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let lastRecord = ruuviStorage.readLast(sensor)
        lastRecord.on(success: { [weak self] record in
            guard let sSelf = self else { return }
            let since: Date = record?.date
                ?? sSelf.ruuviLocalSyncState.lastSyncDate
                ?? networkPuningDate
            let syncOperation = sSelf.syncRecordsOperation(for: sensor, since: since)
            syncOperation.on(success: { [weak sSelf] result in
                promise.succeed(value: result)
                sSelf?.ruuviLocalSyncState.lastSyncDate = Date()
             }, failure: { error in
                promise.fail(error: error)
             })
        }, failure: { [weak self] _ in
            guard let sSelf = self else { return }
            let since: Date = sSelf.ruuviLocalSyncState.lastSyncDate ?? networkPuningDate
            let syncOperation = sSelf.syncRecordsOperation(for: sensor, since: since)
            syncOperation.on(success: { [weak sSelf] result in
                promise.succeed(value: result)
                sSelf?.ruuviLocalSyncState.lastSyncDate = Date()
             }, failure: { (error) in
                promise.fail(error: error)
             })
        })
        return promise.future
    }

    private lazy var syncRecordsQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    private func syncRecordsOperation(
        for sensor: RuuviTagSensor,
        since: Date
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()
        guard let macId = sensor.macId else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        let operation = RuuviServiceCloudSyncRecordsOperation(
            macId: macId,
            since: since,
            ruuviCloud: ruuviCloud,
            ruuviPool: ruuviPool,
            syncState: ruuviLocalSyncState
        )
        operation.completionBlock = { [unowned operation] in
            if let error = operation.error {
                promise.fail(error: error)
            } else {
                promise.succeed(value: operation.records)
            }
        }
        syncRecordsQueue.addOperation(operation)
        return promise.future
    }
}
