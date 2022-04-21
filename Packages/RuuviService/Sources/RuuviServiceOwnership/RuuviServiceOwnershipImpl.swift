import Foundation
import Future
import RuuviOntology
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal
import RuuviService
import RuuviUser

public final class RuuviServiceOwnershipImpl: RuuviServiceOwnership {
    private let cloud: RuuviCloud
    private let pool: RuuviPool
    private let propertiesService: RuuviServiceSensorProperties
    private let localIDs: RuuviLocalIDs
    private let localImages: RuuviLocalImages
    private let storage: RuuviStorage
    private let alertService: RuuviServiceAlert
    private let ruuviUser: RuuviUser

    public init(
        cloud: RuuviCloud,
        pool: RuuviPool,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs,
        localImages: RuuviLocalImages,
        storage: RuuviStorage,
        alertService: RuuviServiceAlert,
        ruuviUser: RuuviUser
    ) {
        self.cloud = cloud
        self.pool = pool
        self.propertiesService = propertiesService
        self.localIDs = localIDs
        self.localImages = localImages
        self.storage = storage
        self.alertService = alertService
        self.ruuviUser = ruuviUser
    }

    @discardableResult
    public func loadShared(for sensor: RuuviTagSensor) -> Future<Set<AnyShareableSensor>, RuuviServiceError> {
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
    public func share(macId: MACIdentifier, with email: String) -> Future<MACIdentifier, RuuviServiceError> {
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
    public func unshare(macId: MACIdentifier, with email: String?) -> Future<MACIdentifier, RuuviServiceError> {
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
    // swiftlint:disable:next function_body_length
    public func claim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        guard let macId = sensor.macId else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        guard let owner = ruuviUser.email else {
            promise.fail(error: .ruuviCloud(.notAuthorized))
            return promise.future
        }
        cloud.claim(name: sensor.name, macId: macId)
            .on(success: { [weak self] _ in
                guard let sSelf = self else { return }
                let claimedSensor = sensor
                    .with(owner: owner)
                    .with(isClaimed: true)
                    .with(isCloudSensor: true)
                sSelf.pool
                    .update(claimedSensor)
                    .on(success: { [weak sSelf] _ in
                        guard let ssSelf = sSelf else { return }
                        if let customImage = ssSelf.localImages.getCustomBackground(for: macId) {
                            if let jpegData = customImage.jpegData(compressionQuality: 1.0) {
                                let remote = ssSelf.cloud.upload(
                                    imageData: jpegData,
                                    mimeType: .jpg,
                                    progress: nil,
                                    for: macId
                                )
                                remote.on(success: { _ in
                                    promise.succeed(value: claimedSensor.any)
                                }, failure: { error in
                                    promise.fail(error: .ruuviCloud(error))
                                })
                            } else {
                                promise.fail(error: .failedToGetJpegRepresentation)
                            }
                        } else {
                            promise.succeed(value: claimedSensor.any)
                        }

                        ssSelf.storage
                            .readSensorSettings(sensor)
                            .on { [weak ssSelf] settings in
                                guard let sssSelf = ssSelf else { return }
                                sssSelf.cloud.update(
                                    temperatureOffset: settings?.temperatureOffset ?? 0,
                                    humidityOffset: (settings?.humidityOffset ?? 0) * 100, // fraction local, % on cloud
                                    pressureOffset: (settings?.pressureOffset ?? 0) * 100, // hPA local, Pa on cloud
                                    for: sensor
                                ).on()
                            }

                        AlertType.allCases.forEach { type in
                            if let alert = ssSelf.alertService.alert(for: sensor, of: type) {
                                ssSelf.alertService.register(type: alert, ruuviTag: claimedSensor)
                            }
                        }
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
    public func unclaim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        guard let macId = sensor.macId else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        cloud.unclaim(macId: macId)
            .on(success: { [weak self] _ in
                guard let sSelf = self else { return }
                let unclaimedSensor = sensor
                    .with(isClaimed: false)
                    .withoutOwner()
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
    public func add(
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
    public func remove(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
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
        localIDs.clear(sensor: sensor)
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
