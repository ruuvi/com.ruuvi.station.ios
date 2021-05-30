import Foundation
import Future
import RuuviOntology
import RuuviPool
import RuuviCloud

final class RuuviServiceSensorPropertiesImpl: RuuviServiceSensorProperties {
    private let pool: RuuviPool
    private let cloud: RuuviCloud

    init(
        pool: RuuviPool,
        cloud: RuuviCloud
    ) {
        self.pool = pool
        self.cloud = cloud
    }

    func set(
        name: String,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        if sensor.isOwner { // TODO: @rinat check if always true for own tags
            cloud.update(name: name, for: sensor)
                .on(success: { [weak self] updatedSensor in
                    guard let sSelf = self else { return }
                    sSelf.pool
                        .update(updatedSensor)
                        .on(success: { _ in
                            promise.succeed(value: updatedSensor)
                        }, failure: { error in
                            promise.fail(error: .ruuviPool(error))
                        })
                }, failure: { error in
                    promise.fail(error: .ruuviCloud(error))
                })
        } else {
            let namedSensor = sensor.with(name: name)
            pool.update(namedSensor)
                .on(success: { _ in
                    promise.succeed(value: namedSensor.any)
                }, failure: { error in
                    promise.fail(error: .ruuviPool(error))
                })
        }
        return promise.future
    }
}
