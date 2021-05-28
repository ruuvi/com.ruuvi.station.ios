import Foundation
import Future
import RuuviOntology
import RuuviStorage
import RuuviCloud
import RuuviPool

final class RuuviServiceCloudSyncImpl: RuuviServiceCloudSync {
    private let ruuviStorage: RuuviStorage
    private let ruuviCloud: RuuviCloud
    private let ruuviPool: RuuviPool

    init(
        ruuviStorage: RuuviStorage,
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviCloud = ruuviCloud
        self.ruuviPool = ruuviPool
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
}
