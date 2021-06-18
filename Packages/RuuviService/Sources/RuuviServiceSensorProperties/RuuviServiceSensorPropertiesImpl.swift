import Foundation
import UIKit
import Future
import RuuviOntology
import RuuviPool
import RuuviCloud
import RuuviLocal
import RuuviCore
import RuuviService

public final class RuuviServiceSensorPropertiesImpl: RuuviServiceSensorProperties {
    private let pool: RuuviPool
    private let cloud: RuuviCloud
    private let coreImage: RuuviCoreImage
    private let localImages: RuuviLocalImages

    public init(
        pool: RuuviPool,
        cloud: RuuviCloud,
        coreImage: RuuviCoreImage,
        localImages: RuuviLocalImages
    ) {
        self.pool = pool
        self.cloud = cloud
        self.coreImage = coreImage
        self.localImages = localImages
    }

    public func set(
        name: String,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        if sensor.isCloud {
            let namedSensor = sensor.with(name: name)
            pool.update(namedSensor)
                .on(success: { [weak self] _ in
                    self?.cloud.update(name: name, for: sensor)
                    promise.succeed(value: namedSensor.any)
                }, failure: { error in
                    promise.fail(error: .ruuviPool(error))
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

    public func set(
        image: UIImage,
        for sensor: VirtualSensor
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        localImages.setCustomBackground(
            image: image,
            for: sensor.id.luid
        ).on(success: { url in
            promise.succeed(value: url)
        }, failure: { error in
            promise.fail(error: .ruuviLocal(error))
        })
        return promise.future
    }

    public func setNextDefaultBackground(for sensor: VirtualSensor) -> Future<UIImage, RuuviServiceError> {
        let luid = sensor.id.luid
        let macId: MACIdentifier? = nil
        return setNextDefaultBackground(luid: luid, macId: macId)
    }

    public func setNextDefaultBackground(for sensor: RuuviTagSensor) -> Future<UIImage, RuuviServiceError> {
        let luid = sensor.luid
        let macId = sensor.macId
        if sensor.isCloud {
            resetCloudImage(for: sensor).on()
        }
        return setNextDefaultBackground(luid: luid, macId: macId)
    }

    public func setNextDefaultBackground(luid: LocalIdentifier?, macId: MACIdentifier?) -> Future<UIImage, RuuviServiceError> {
        let promise = Promise<UIImage, RuuviServiceError>()
        let identifier = macId ?? luid
        if let identifier = identifier {
            if let image = localImages.setNextDefaultBackground(for: identifier) {
                promise.succeed(value: image)
            } else {
                promise.fail(error: .failedToFindOrGenerateBackgroundImage)
            }
        } else {
            promise.fail(error: .bothLuidAndMacAreNil)
        }
        return promise.future
    }

    // swiftlint:disable:next function_body_length
    public func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        let croppedImage = coreImage.cropped(image: image, to: maxSize)
        guard let jpegData = croppedImage.jpegData(compressionQuality: 1.0) else {
            promise.fail(error: .failedToGetJpegRepresentation)
            return promise.future
        }
        let luid = sensor.luid
        let macId = sensor.macId
        assert(luid != nil || macId != nil)
        var local: Future<URL, RuuviLocalError>?
        var remote: Future<URL, RuuviCloudError>?
        if sensor.isCloud {
            if let mac = macId {
                remote = cloud.upload(
                    imageData: jpegData,
                    mimeType: .jpg,
                    progress: { macId, percentage in
                        self.localImages.setBackgroundUploadProgress(
                            percentage: percentage,
                            for: macId
                        )
                        progress?(macId, percentage)
                    },
                    for: mac
                )
                local = localImages.setCustomBackground(image: image, for: mac)
            } else if let luid = luid {
                local = localImages.setCustomBackground(image: image, for: luid)
            } else {
                promise.fail(error: .bothLuidAndMacAreNil)
                return promise.future
            }
        } else {
            if let mac = macId {
                local = localImages.setCustomBackground(image: image, for: mac)
            } else if let luid = luid {
                local = localImages.setCustomBackground(image: image, for: luid)
            } else {
                promise.fail(error: .bothLuidAndMacAreNil)
                return promise.future
            }
        }

        if let local = local, let remote = remote {
            if let mac = macId {
                localImages.setBackgroundUploadProgress(percentage: 0.0, for: mac)
            }
            remote.on(success: {_ in
                local.on(success: { localUrl in
                    if let mac = macId {
                        self.localImages.deleteBackgroundUploadProgress(for: mac)
                    }
                    promise.succeed(value: localUrl)
                }, failure: { error in
                    promise.fail(error: .ruuviLocal(error))
                })
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        } else if let local = local {
            local.on(success: { url in
                promise.succeed(value: url)
            }, failure: { error in
                promise.fail(error: .ruuviLocal(error))
            })
        } else {
            promise.fail(error: .bothLuidAndMacAreNil)
            return promise.future
        }
        return promise.future
    }

    public func getImage(for sensor: VirtualSensor) -> Future<UIImage, RuuviServiceError> {
        let luid = sensor.id.luid
        let macId: MACIdentifier? = nil
        return getImage(luid: luid, macId: macId)
    }

    public func getImage(for sensor: RuuviTagSensor) -> Future<UIImage, RuuviServiceError> {
        return getImage(luid: sensor.luid, macId: sensor.macId)
    }

    public func removeImage(for sensor: RuuviTagSensor) {
        if let macId = sensor.macId {
            localImages.deleteCustomBackground(for: macId)
        }
        if let luid = sensor.luid {
            localImages.deleteCustomBackground(for: luid)
        }
        localImages.setPictureRemovedFromCache(for: sensor)
        if sensor.isCloud {
            resetCloudImage(for: sensor)
        }
    }

    public func removeImage(for sensor: VirtualSensor) {
        localImages.deleteCustomBackground(for: sensor.id.luid)
    }

    private func resetCloudImage(for sensor: RuuviTagSensor) -> Future<Void, RuuviServiceError> {
        let promise = Promise<Void, RuuviServiceError>()
        guard let macId = sensor.macId else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        cloud.resetImage(for: macId)
            .on(success: { _ in
                promise.succeed(value: ())
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    private func getImage(luid: LocalIdentifier?, macId: MACIdentifier?) -> Future<UIImage, RuuviServiceError> {
        let promise = Promise<UIImage, RuuviServiceError>()
        if let macId = macId {
            if let image = localImages.getBackground(for: macId) {
                promise.succeed(value: image)
            } else if let luid = luid, let image = localImages.getOrGenerateBackground(for: luid) {
                promise.succeed(value: image)
            } else if let image = localImages.getOrGenerateBackground(for: macId) {
                promise.succeed(value: image)
            } else {
                promise.fail(error: .failedToFindOrGenerateBackgroundImage)
            }
        } else if let luid = luid {
            if let image = localImages.getOrGenerateBackground(for: luid) {
                promise.succeed(value: image)
            } else {
                promise.fail(error: .failedToFindOrGenerateBackgroundImage)
            }
        } else {
            promise.fail(error: .bothLuidAndMacAreNil)
        }
        return promise.future
    }
}
