import Foundation
import Future
import RuuviOntology
import RuuviStorage
import RuuviCloud
import RuuviPool

final class RuuviServiceOwnershipImpl: RuuviServiceOwnership {
    private let cloud: RuuviCloud
    private let pool: RuuviPool

    init(
        cloud: RuuviCloud,
        pool: RuuviPool
    ) {
        self.cloud = cloud
        self.pool = pool
    }

    @discardableResult
    func claim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        guard let macId = sensor.macId else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        cloud.claim(macId: macId)
            .on(success: { [weak self] _ in
                guard let sSelf = self else { return }
                let claimedSensor = sensor.with(isClaimed: true)
                sSelf.pool
                    .update(claimedSensor)
                    .on(success: { _ in
                        promise.succeed(value: claimedSensor.any)
                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })
            }, failure: { error in
                // TODO: @rinat check login on use cases
                // if error.errorDescription == "Sensor already claimed" {
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    func unclaim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        guard let macId = sensor.macId else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        cloud.unclaim(macId: macId)
            .on(success: { [weak self] _ in
                guard let sSelf = self else { return }
                let unclaimedSensor = sensor.with(isClaimed: false)
                sSelf.pool
                    .update(unclaimedSensor)
                    .on(success: { _ in
                        promise.succeed(value: unclaimedSensor.any)
                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }
}
