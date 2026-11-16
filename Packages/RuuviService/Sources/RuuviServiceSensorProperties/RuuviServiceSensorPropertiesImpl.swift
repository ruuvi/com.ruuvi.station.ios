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
        let updatedSensor = sensor.with(name: name).with(lastUpdated: Date())
        if sensor.isCloud {
            pool.update(updatedSensor)
                .on(success: { [weak self] _ in
                    self?.cloud.update(name: name, for: sensor)
                    promise.succeed(value: updatedSensor.any)
                }, failure: { error in
                    promise.fail(error: .ruuviPool(error))
                })
        } else {
            pool.update(updatedSensor)
                .on(success: { _ in
                    promise.succeed(value: updatedSensor.any)
                }, failure: { error in
                    promise.fail(error: .ruuviPool(error))
                })
        }
        return promise.future
    }

    public func setNextDefaultBackground(for sensor: RuuviTagSensor) -> Future<UIImage, RuuviServiceError> {
        let luid = sensor.luid
        let macId = sensor.macId
        let result = setNextDefaultBackground(luid: luid, macId: macId)
        result.on(success: { [weak self] _ in
            self?.updateSensorTimestamp(for: sensor)
        })
        return result
    }

    public func setNextDefaultBackground(
        luid: LocalIdentifier?,
        macId: MACIdentifier?
    ) -> Future<UIImage, RuuviServiceError> {
        let promise = Promise<UIImage, RuuviServiceError>()
        let identifier = macId ?? luid
        if let identifier {
            // A Bluetooth-only selection must not survive a switch to a default via its MAC alias.
            if let luid, macId != nil {
                localImages.deleteCustomBackground(for: luid)
            }
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

    public func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        let imageTimestamp = Date()
        let croppedImage = coreImage.cropped(image: image, to: maxSize)
        guard let identifier = sensor.macId ?? sensor.luid else {
            promise.fail(error: .bothLuidAndMacAreNil)
            return promise.future
        }
        localImages.setUserSelectedBackground(
            image: croppedImage, compressionQuality: compressionQuality, selectedAt: imageTimestamp, for: identifier
        ).on(success: { localUrl in
            guard self.localImages.customBackgroundLastUpdated(for: identifier) == imageTimestamp else {
                promise.succeed(value: localUrl)
                return
            }
            self.updateSensorTimestamp(for: sensor)
            guard sensor.isCloud, let macId = sensor.macId else {
                promise.succeed(value: localUrl)
                return
            }
            self.localImages.setBackgroundUploadProgress(percentage: 0, for: macId)
            self.localImages.backgroundUploadData(for: identifier)
                .mapError { RuuviServiceError.ruuviLocal($0) }
                .flatMap { jpegData in
                    self.cloud.upload(
                        imageData: jpegData, mimeType: .jpg, lastUpdated: imageTimestamp,
                        progress: { macId, percentage in
                            self.localImages.setBackgroundUploadProgress(percentage: percentage, for: macId)
                            progress?(macId, percentage)
                        },
                        isCurrentSelection: {
                            self.localImages.customBackgroundLastUpdated(for: identifier) == imageTimestamp
                        },
                        for: macId
                    ).mapError { RuuviServiceError.ruuviCloud($0) }
                }.on(success: { url in
                    self.localImages.acknowledgeBackgroundUpload(url, selectedAt: imageTimestamp, for: identifier)
                    self.localImages.deleteBackgroundUploadProgress(for: macId)
                    promise.succeed(value: localUrl)
                }, failure: { promise.fail(error: $0) })
        }, failure: { promise.fail(error: .ruuviLocal($0)) })
        return promise.future
    }

    public func getImage(for sensor: RuuviTagSensor) -> Future<UIImage, RuuviServiceError> {
        if let pending = localImages.userSelectedBackground(for: sensor) {
            return Future(value: pending.image)
        }
        let dataFormat = RuuviDataFormat.dataFormat(from: sensor.version)
        let ruuviDeviceType: RuuviDeviceType = dataFormat == .e1 || dataFormat == .v6 ? .ruuviAir : .ruuviTag
        return getImage(luid: sensor.luid, macId: sensor.macId, ruuviDeviceType: ruuviDeviceType)
    }

    public func removeImage(for sensor: RuuviTagSensor) {
        if let macId = sensor.macId {
            localImages.deleteCustomBackground(for: macId)
        }
        if let luid = sensor.luid {
            localImages.deleteCustomBackground(for: luid)
        }
        localImages.setPictureRemovedFromCache(for: sensor)
        updateSensorTimestamp(for: sensor)
    }

    @discardableResult
    // swiftlint:disable:next function_body_length
    public func updateDisplaySettings(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) -> Future<SensorSettings, RuuviServiceError> {
        let promise = Promise<SensorSettings, RuuviServiceError>()
        let updatedAt = Date()

        // Fetch current settings to determine which timestamps to update
        pool.readSensorSettings(sensor)
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] currentSettings in
                guard let self = self else {
                    promise.fail(
                        error: .ruuviCloud(.api(.failedToGetDataFromResponse))
                    )
                    return
                }

                // Determine which timestamps to update based on what changed
                var displayOrderTimestamp: Date?
                var defaultDisplayOrderTimestamp: Date?

                // Update displayOrder timestamp only if the value changed
                if let currentDisplayOrder = currentSettings?.displayOrder,
                   let newDisplayOrder = displayOrder {
                    if currentDisplayOrder != newDisplayOrder {
                        displayOrderTimestamp = updatedAt
                    }
                } else if displayOrder != nil {
                    // New value being set, no previous value
                    displayOrderTimestamp = updatedAt
                }

                // Update defaultDisplayOrder timestamp only if the value changed
                if let currentDefaultDisplayOrder = currentSettings?.defaultDisplayOrder {
                    if currentDefaultDisplayOrder != defaultDisplayOrder {
                        defaultDisplayOrderTimestamp = updatedAt
                    }
                } else {
                    // New value being set, no previous value
                    defaultDisplayOrderTimestamp = updatedAt
                }

                self.pool
                    .updateDisplaySettings(
                        for: sensor,
                        displayOrder: displayOrder,
                        defaultDisplayOrder: defaultDisplayOrder,
                        displayOrderLastUpdated: displayOrderTimestamp,
                        defaultDisplayOrderLastUpdated: defaultDisplayOrderTimestamp
                    )
                    .on(success: { [weak self] settings in
                        if sensor.isCloud {
                            self?.pushDisplaySettingsToCloudIfNeeded(
                                for: sensor,
                                displayOrder: displayOrder,
                                defaultDisplayOrder: defaultDisplayOrder
                            ).on(success: { _ in
                                promise.succeed(value: settings)
                            }, failure: { error in
                                promise.fail(error: error)
                            })
                        } else {
                            promise.succeed(value: settings)
                        }
                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })

        return promise.future
    }

    @discardableResult
    public func updateDescription(
        for sensor: RuuviTagSensor,
        description: String?
    ) -> Future<SensorSettings, RuuviServiceError> {
        let promise = Promise<SensorSettings, RuuviServiceError>()
        let updatedAt = Date()

        pool.readSensorSettings(sensor)
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] currentSettings in
                guard let self else {
                    promise.fail(
                        error: .ruuviCloud(.api(.failedToGetDataFromResponse))
                    )
                    return
                }

                let descriptionTimestamp: Date? =
                    currentSettings?.description != description ? updatedAt : nil

                self.pool.updateDescription(
                    for: sensor,
                    description: description,
                    descriptionLastUpdated: descriptionTimestamp
                ).on(success: { [weak self] settings in
                    if sensor.isCloud {
                        self?.pushDescriptionToCloudIfNeeded(
                            for: sensor,
                            description: description
                        ).on(success: { _ in
                            promise.succeed(value: settings)
                        }, failure: { error in
                            promise.fail(error: error)
                        })
                    } else {
                        promise.succeed(value: settings)
                    }
                }, failure: { error in
                    promise.fail(error: .ruuviPool(error))
                })
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
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

    private func pushDescriptionToCloudIfNeeded(
        for sensor: RuuviTagSensor,
        description: String?
    ) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        guard sensor.isCloud else { return promise.future }

        cloud.updateSensorSettings(
            for: sensor,
            types: [RuuviCloudApiSetting.sensorDescription.rawValue],
            values: [description ?? ""],
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

    private func updateSensorTimestamp(for sensor: RuuviTagSensor) {
        let updatedSensor = sensor.with(lastUpdated: Date())
        pool.update(updatedSensor).on()
    }
}
