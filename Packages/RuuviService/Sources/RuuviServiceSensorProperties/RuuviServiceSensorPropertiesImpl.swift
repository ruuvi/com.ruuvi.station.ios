import Foundation
import Future
import RuuviCloud
import RuuviCore
import RuuviLocal
import RuuviOntology
import RuuviPool
import UIKit

// swiftlint:disable:next type_body_length
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

    public func setNextDefaultBackground(for sensor: RuuviTagSensor) -> Future<UIImage, RuuviServiceError> {
        let luid = sensor.luid
        let macId = sensor.macId
        if sensor.isCloud {
            resetCloudImage(for: sensor).on()
        }
        return setNextDefaultBackground(luid: luid, macId: macId)
    }

    public func setNextDefaultBackground(
        luid: LocalIdentifier?,
        macId: MACIdentifier?
    ) -> Future<UIImage, RuuviServiceError> {
        let promise = Promise<UIImage, RuuviServiceError>()
        let identifier = macId ?? luid
        if let identifier {
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
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        let croppedImage = coreImage.cropped(image: image, to: maxSize)
        guard let jpegData = croppedImage.jpegData(compressionQuality: compressionQuality)
        else {
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
                local = localImages.setCustomBackground(
                    image: croppedImage,
                    compressionQuality: compressionQuality,
                    for: mac
                )
            } else if let luid {
                local = localImages.setCustomBackground(
                    image: croppedImage,
                    compressionQuality: compressionQuality,
                    for: luid
                )
            } else {
                promise.fail(error: .bothLuidAndMacAreNil)
                return promise.future
            }
        } else {
            if let mac = macId {
                local = localImages.setCustomBackground(
                    image: croppedImage,
                    compressionQuality: compressionQuality,
                    for: mac
                )
            } else if let luid {
                local = localImages.setCustomBackground(
                    image: croppedImage,
                    compressionQuality: compressionQuality,
                    for: luid
                )
            } else {
                promise.fail(error: .bothLuidAndMacAreNil)
                return promise.future
            }
        }

        if let local, let remote {
            if let mac = macId {
                localImages.setBackgroundUploadProgress(percentage: 0.0, for: mac)
            }
            remote.on(success: { _ in
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
        } else if let local {
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

    public func getImage(for sensor: RuuviTagSensor) -> Future<UIImage, RuuviServiceError> {
        let dataFormat = RuuviDataFormat.dataFormat(from: sensor.version)
        let ruuviDeviceType: RuuviDeviceType =
            dataFormat == .e1 || dataFormat == .v6 ? .ruuviAir : .ruuviTag
        return getImage(
            luid: sensor.luid,
            macId: sensor.macId,
            ruuviDeviceType: ruuviDeviceType
        )
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

    @discardableResult
    public func updateDisplaySettings(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) -> Future<SensorSettings, RuuviServiceError> {
        let promise = Promise<SensorSettings, RuuviServiceError>()

        pool
            .updateDisplaySettings(
                for: sensor,
                displayOrder: displayOrder,
                defaultDisplayOrder: defaultDisplayOrder
            )
            .on(success: { [weak self] settings in
                self?.pushDisplaySettingsToCloudIfNeeded(
                    for: sensor,
                    displayOrder: displayOrder,
                    defaultDisplayOrder: defaultDisplayOrder
                ).on(success: { _ in
                    promise.succeed(value: settings)
                }, failure: { error in
                    promise.fail(error: error)
                })
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })

        return promise.future
    }

    @discardableResult
    private func resetCloudImage(for sensor: RuuviTagSensor) -> Future<Void, RuuviServiceError> {
        let promise = Promise<Void, RuuviServiceError>()
        guard let macId = sensor.macId
        else {
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

    private func getImage(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        ruuviDeviceType: RuuviDeviceType
    ) -> Future<UIImage, RuuviServiceError> {
        let promise = Promise<UIImage, RuuviServiceError>()
        if let macId {
            if let image = localImages.getBackground(for: macId) {
                promise.succeed(value: image)
            } else if let luid, let image = localImages.getOrGenerateBackground(
                for: luid,
                ruuviDeviceType: ruuviDeviceType
            ) {
                promise.succeed(value: image)
            } else if let image = localImages.getOrGenerateBackground(
                for: macId,
                ruuviDeviceType: ruuviDeviceType
            ) {
                promise.succeed(value: image)
            } else {
                promise.fail(error: .failedToFindOrGenerateBackgroundImage)
            }
        } else if let luid {
            if let image = localImages.getOrGenerateBackground(
                for: luid,
                ruuviDeviceType: ruuviDeviceType
            ) {
                promise.succeed(value: image)
            } else {
                promise.fail(error: .failedToFindOrGenerateBackgroundImage)
            }
        } else {
            promise.fail(error: .bothLuidAndMacAreNil)
        }
        return promise.future
    }

    private func pushDisplaySettingsToCloudIfNeeded(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()

        guard sensor.isCloud else { return promise.future }

        var types: [String] = [RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue]
        var values: [String] = [defaultDisplayOrder ? "true" : "false"]

        if let encodedOrder = encodeDisplayOrderForCloud(displayOrder) {
            types.append(RuuviCloudApiSetting.sensorDisplayOrder.rawValue)
            values.append(encodedOrder)
        }

        cloud.updateSensorSettings(
            for: sensor,
            types: types,
            values: values,
            timestamp: Int(Date().timeIntervalSince1970)
        ).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: .ruuviCloud(error))
        })

        return promise.future
    }

    private func encodeDisplayOrderForCloud(_ codes: [String]?) -> String? {
        guard let codes, !codes.isEmpty else {
            return nil
        }
        if let data = try? JSONEncoder().encode(codes),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        if let data = try? JSONSerialization.data(withJSONObject: codes, options: []),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }
}
