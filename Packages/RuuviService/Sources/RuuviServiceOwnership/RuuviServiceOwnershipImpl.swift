import Foundation
import Future
import RuuviOntology
import RuuviStorage
import RuuviCloud
import RuuviPool

final class RuuviServiceOwnershipImpl: RuuviServiceOwnership {
    private let cloud: RuuviCloud
    private let pool: RuuviPool
    private let propertiesService: RuuviServiceSensorProperties

    init(
        cloud: RuuviCloud,
        pool: RuuviPool,
        propertiesService: RuuviServiceSensorProperties
    ) {
        self.cloud = cloud
        self.pool = pool
        self.propertiesService = propertiesService
    }

    @discardableResult
    func loadShared(for sensor: RuuviTagSensor) -> Future<Set<AnyShareableSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyShareableSensor>, RuuviServiceError>()
        cloud.loadShared(for: sensor)
            .on(success: { shareableSensors in
                promise.succeed(value: shareableSensors)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    func share(macId: MACIdentifier, with email: String) -> Future<MACIdentifier, RuuviServiceError> {
        let promise = Promise<MACIdentifier, RuuviServiceError>()
        cloud.share(macId: macId, with: email)
            .on(success: { macId in
                promise.succeed(value: macId)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    func unshare(macId: MACIdentifier, with email: String?) -> Future<MACIdentifier, RuuviServiceError> {
        let promise = Promise<MACIdentifier, RuuviServiceError>()
        cloud.unshare(macId: macId, with: email)
            .on(success: { macId in
                promise.succeed(value: macId)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
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
                // TODO: @rinat check on use cases
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

    @discardableResult
    func add(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        let entity = pool.create(sensor)
        let record = pool.create(record)
        Future.zip(entity, record).on(success: { _ in
            promise.succeed(value: sensor.any)
        }, failure: { error in
            promise.fail(error: .ruuviPool(error))
        })
        return promise.future
    }

    @discardableResult
    func remove(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        let deleteTagOperation = pool.delete(sensor)
        let deleteRecordsOperation = pool.deleteAllRecords(sensor.id)
        var unshareOperation: Future<MACIdentifier, RuuviServiceError>?
        var unclaimOperation: Future<AnyRuuviTagSensor, RuuviServiceError>?
        if let macId = sensor.macId,
           sensor.isCloud {
            if sensor.isOwner {
                unclaimOperation = unclaim(sensor: sensor)
            } else {
                unshareOperation = unshare(macId: macId, with: nil)
            }
        }
        propertiesService.removeImage(for: sensor)
        Future.zip([deleteTagOperation, deleteRecordsOperation])
            .on(success: { _ in
                if let unclaimOperation = unclaimOperation {
                    unclaimOperation.on()
                    promise.succeed(value: sensor.any)
                } else if let unshareOperation = unshareOperation {
                    unshareOperation.on()
                    promise.succeed(value: sensor.any)
                } else {
                    promise.succeed(value: sensor.any)
                }
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })
        return promise.future
    }
}
