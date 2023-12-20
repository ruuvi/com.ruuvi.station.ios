import Foundation
import Future
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviStorage
import RuuviUser

public extension Notification.Name {
    static let RuuviTagOwnershipCheckDidEnd = Notification.Name("RuuviTagOwnershipCheckDidEnd")
}

public enum RuuviTagOwnershipCheckResultKey: String {
    case hasOwner = "hasTagOwner"
}

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
    public func share(
        macId: MACIdentifier,
        with email: String
    ) -> Future<ShareSensorResponse, RuuviServiceError> {
        let promise = Promise<ShareSensorResponse, RuuviServiceError>()
        cloud.share(macId: macId, with: email)
            .on(success: { result in
                promise.succeed(value: result)
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
    public func claim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        guard let macId = sensor.macId
        else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        guard let owner = ruuviUser.email
        else {
            promise.fail(error: .ruuviCloud(.notAuthorized))
            return promise.future
        }
        cloud.claim(name: sensor.name, macId: macId)
            .on(success: { [weak self] _ in
                self?.handleSensorClaimed(
                    sensor: sensor,
                    owner: owner,
                    macId: macId,
                    promise: promise
                )
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func contest(
        sensor: RuuviTagSensor,
        secret: String
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        guard let macId = sensor.macId
        else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }

        guard let owner = ruuviUser.email
        else {
            promise.fail(error: .ruuviCloud(.notAuthorized))
            return promise.future
        }

        cloud.contest(macId: macId, secret: secret)
            .on(success: { [weak self] _ in
                self?.handleSensorClaimed(
                    sensor: sensor,
                    owner: owner,
                    macId: macId,
                    promise: promise
                )
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func unclaim(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        guard let macId = sensor.macId
        else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        cloud.unclaim(
            macId: macId,
            removeCloudHistory: removeCloudHistory
        )
        .on(success: { [weak self] _ in
            guard let sSelf = self else { return }
            let unclaimedSensor = sensor
                .with(isClaimed: false)
                .with(canShare: false)
                .with(sharedTo: [])
                .with(isCloudSensor: false)
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
        let recordEntity = pool.create(record)
        let recordLast = pool.createLast(record)
        Future.zip(entity, recordEntity, recordLast).on(success: { _ in
            promise.succeed(value: sensor.any)
        }, failure: { error in
            promise.fail(error: .ruuviPool(error))
        })
        return promise.future
    }

    @discardableResult
    public func remove(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        let deleteTagOperation = pool.delete(sensor)
        let deleteRecordsOperation = pool.deleteAllRecords(sensor.id)
        let deleteLastRecordOperation = pool.deleteLast(sensor.id)
        let cleanUpOperation = pool.cleanupDBSpace()
        var unshareOperation: Future<MACIdentifier, RuuviServiceError>?
        var unclaimOperation: Future<AnyRuuviTagSensor, RuuviServiceError>?
        if let macId = sensor.macId,
           sensor.isCloud {
            if sensor.isOwner {
                unclaimOperation = unclaim(
                    sensor: sensor,
                    removeCloudHistory: removeCloudHistory
                )
            } else {
                unshareOperation = unshare(macId: macId, with: nil)
            }
        }
        propertiesService.removeImage(for: sensor)
        localIDs.clear(sensor: sensor)
        Future.zip([
            deleteTagOperation,
            deleteRecordsOperation,
            deleteLastRecordOperation,
        ])
        .on(success: { _ in
            if let unclaimOperation {
                unclaimOperation.on()
                promise.succeed(value: sensor.any)
            } else if let unshareOperation {
                unshareOperation.on()
                promise.succeed(value: sensor.any)
            } else {
                promise.succeed(value: sensor.any)
            }
        }, failure: { error in
            promise.fail(error: .ruuviPool(error))
        }, completion: {
            cleanUpOperation.on()
        })
        return promise.future
    }

    @discardableResult
    public func checkOwner(macId: MACIdentifier) -> Future<String?, RuuviServiceError> {
        let promise = Promise<String?, RuuviServiceError>()
        cloud.checkOwner(macId: macId)
            .on(success: { owner in
                promise.succeed(value: owner)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func updateShareable(for sensor: RuuviTagSensor) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        pool.update(sensor).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: .ruuviPool(error))
        })
        return promise.future
    }
}

extension RuuviServiceOwnershipImpl {
    private func handleSensorClaimed(
        sensor: RuuviTagSensor,
        owner: String,
        macId: MACIdentifier,
        promise: Promise<AnyRuuviTagSensor, RuuviServiceError>
    ) {
        let claimedSensor = sensor
            .with(owner: owner)
            .with(isClaimed: true)
            .with(isCloudSensor: true)
            .with(isOwner: true)
        pool
            .update(claimedSensor)
            .on(success: { [weak self] _ in
                self?.handleUpdatedSensor(
                    sensor: claimedSensor,
                    promise: promise,
                    macId: macId
                )
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })
    }

    private func handleUpdatedSensor(
        sensor: RuuviTagSensor,
        promise: Promise<AnyRuuviTagSensor, RuuviServiceError>,
        macId: MACIdentifier
    ) {
        if let customImage = localImages.getCustomBackground(for: macId) {
            if let jpegData = customImage.jpegData(compressionQuality: 1.0) {
                let remote = cloud.upload(
                    imageData: jpegData,
                    mimeType: .jpg,
                    progress: nil,
                    for: macId
                )
                remote.on(success: { _ in
                    promise.succeed(value: sensor.any)
                }, failure: { error in
                    promise.fail(error: .ruuviCloud(error))
                })
            } else {
                promise.fail(error: .failedToGetJpegRepresentation)
            }
        } else {
            promise.succeed(value: sensor.any)
        }

        storage
            .readSensorSettings(sensor)
            .on { [weak self] settings in
                guard let sSelf = self else { return }
                sSelf.cloud.update(
                    temperatureOffset: settings?.temperatureOffset ?? 0,
                    humidityOffset: (settings?.humidityOffset ?? 0) * 100, // fraction local, % on cloud
                    pressureOffset: (settings?.pressureOffset ?? 0) * 100, // hPA local, Pa on cloud
                    for: sensor
                ).on()
            }

        AlertType.allCases.forEach { type in
            if let alert = alertService.alert(for: sensor, of: type) {
                alertService.register(type: alert, ruuviTag: sensor)
            }
        }
    }
}
