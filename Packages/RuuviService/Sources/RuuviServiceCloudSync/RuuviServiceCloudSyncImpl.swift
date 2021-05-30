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
    private let ruuviLocalImages: RuuviLocalImages

    init(
        ruuviStorage: RuuviStorage,
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        ruuviLocalSettings: RuuviLocalSettings,
        ruuviLocalSyncState: RuuviLocalSyncState,
        ruuviLocalImages: RuuviLocalImages
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviCloud = ruuviCloud
        self.ruuviPool = ruuviPool
        self.ruuviLocalSettings = ruuviLocalSettings
        self.ruuviLocalSyncState = ruuviLocalSyncState
        self.ruuviLocalImages = ruuviLocalImages
    }

    @discardableResult
    func syncImage(sensor: CloudSensor) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        guard let pictureUrl = sensor.picture else {
            promise.fail(error: .pictureUrlIsNil)
            return promise.future
        }
        URLSession
            .shared
            .dataTask(with: pictureUrl, completionHandler: { [weak self] data, _, error in
                guard let sSelf = self else { return }
                if let error = error {
                    promise.fail(error: .networking(error))
                } else if let data = data {
                    if let image = UIImage(data: data) {
                        sSelf.ruuviLocalImages
                            .setCustomBackground(image: image, for: sensor.id.mac)
                            .on(success: { [weak sSelf] fileUrl in
                                guard let ssSelf = sSelf else { return }
                                ssSelf.ruuviLocalImages.setPictureIsCached(for: sensor)
                                promise.succeed(value: fileUrl)
                            }, failure: { error in
                                promise.fail(error: .ruuviLocal(error))
                            })
                    } else {
                        promise.fail(error: .failedToParseNetworkResponse)
                    }
                } else {
                    promise.fail(error: .failedToParseNetworkResponse)
                }
            }).resume()
        return promise.future
    }

    @discardableResult
    func syncAll() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()
        let sensors = syncSensors()
        sensors.on(success: { [weak self] updatedSensors in
            guard let sSelf = self else { return }
            let syncs = updatedSensors.map({ sSelf.sync(sensor: $0) })
            Future.zip(syncs).on(success: { _ in
                promise.succeed(value: updatedSensors)
            }, failure: { error in
                promise.fail(error: error)
            })
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    @discardableResult
    func syncAllRecords() -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()
        ruuviStorage.readAll().on(success: { [weak self] localSensors in
            guard let sSelf = self else { return }
            let syncs = localSensors.map({ sSelf.sync(sensor: $0) })
            Future.zip(syncs).on(success: { remoteSensorRecords in
                promise.succeed(value: remoteSensorRecords.reduce([], +))
            }, failure: { error in
                promise.fail(error: error)
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })
        return promise.future
    }

    @discardableResult
    func syncSensors() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()
        var updatedSensors = Set<AnyRuuviTagSensor>()
        ruuviStorage.readAll().on(success: { [weak self] localSensors in
            guard let sSelf = self else { return }
            sSelf.ruuviCloud.loadSensors().on(success: { cloudSensors in
                let updateSensors: [Future<Bool, RuuviPoolError>] = localSensors
                    .compactMap({ localSensor in
                        if let cloudSensor = cloudSensors.first(where: {$0.id == localSensor.id }) {
                            updatedSensors.insert(localSensor)
                            return sSelf.ruuviPool.update(localSensor.with(cloudSensor: cloudSensor))
                        } else {
                            let unclaimed = localSensor.unclaimed()
                            if unclaimed.any != localSensor {
                                updatedSensors.insert(localSensor)
                                return sSelf.ruuviPool.update(unclaimed)
                            } else {
                                return nil
                            }
                        }
                    })
                let createSensors: [Future<Bool, RuuviPoolError>] = cloudSensors
                    .filter { cloudSensor in
                        !localSensors.contains(where: { $0.id == cloudSensor.id })
                    }.map { newCloudSensor in
                        let newLocalSensor = newCloudSensor.ruuviTagSensor
                        updatedSensors.insert(newLocalSensor.any)
                        return sSelf.ruuviPool.create(newLocalSensor)
                    }

                let syncImages = cloudSensors
                    .filter({ !sSelf.ruuviLocalImages.isPictureCached(for: $0) })
                    .map({ sSelf.syncImage(sensor: $0) })

                Future.zip([Future.zip(createSensors), Future.zip(updateSensors)]).on(success: { _ in
                    Future.zip(syncImages).on()
                    promise.succeed(value: updatedSensors)
                }, failure: { error in
                    promise.fail(error: .ruuviPool(error))
                })
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
                sSelf?.ruuviLocalSyncState.lastSyncDate = Date()
                promise.succeed(value: result)
             }, failure: { error in
                promise.fail(error: error)
             })
        }, failure: { [weak self] _ in
            guard let sSelf = self else { return }
            let since: Date = sSelf.ruuviLocalSyncState.lastSyncDate ?? networkPuningDate
            let syncOperation = sSelf.syncRecordsOperation(for: sensor, since: since)
            syncOperation.on(success: { [weak sSelf] result in
                sSelf?.ruuviLocalSyncState.lastSyncDate = Date()
                promise.succeed(value: result)
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
