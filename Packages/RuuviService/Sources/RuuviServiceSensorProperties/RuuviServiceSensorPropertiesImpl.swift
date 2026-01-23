import Foundation
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
    ) async throws -> AnyRuuviTagSensor {
        let namedSensor = sensor.with(name: name)
        do {
            _ = try await pool.update(namedSensor)
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }
        if sensor.isCloud {
            Task { [cloud] in
                _ = try? await cloud.update(name: name, for: sensor)
            }
        }
        return namedSensor.any
    }

    public func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws -> UIImage {
        let luid = sensor.luid
        let macId = sensor.macId
        if sensor.isCloud {
            Task { [weak self] in
                _ = try? await self?.resetCloudImage(for: sensor)
            }
        }
        return try await setNextDefaultBackground(luid: luid, macId: macId)
    }

    public func setNextDefaultBackground(
        luid: LocalIdentifier?,
        macId: MACIdentifier?
    ) async throws -> UIImage {
        let identifier = macId ?? luid
        if let identifier {
            if let image = localImages.setNextDefaultBackground(for: identifier) {
                return image
            } else {
                throw RuuviServiceError.failedToFindOrGenerateBackgroundImage
            }
        } else {
            throw RuuviServiceError.bothLuidAndMacAreNil
        }
    }

    // swiftlint:disable:next function_body_length
    public func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) async throws -> URL {
        let croppedImage = coreImage.cropped(image: image, to: maxSize)
        guard let jpegData = croppedImage.jpegData(compressionQuality: compressionQuality)
        else {
            throw RuuviServiceError.failedToGetJpegRepresentation
        }
        let luid = sensor.luid
        let macId = sensor.macId
        assert(luid != nil || macId != nil)
        if sensor.isCloud {
            if let mac = macId {
                localImages.setBackgroundUploadProgress(percentage: 0.0, for: mac)
                let localTask = Task {
                    try await localImages.setCustomBackground(
                        image: croppedImage,
                        compressionQuality: compressionQuality,
                        for: mac
                    )
                }
                let remoteTask = Task {
                    try await cloud.upload(
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
                }
                do {
                    _ = try await remoteTask.value
                } catch let error as RuuviCloudError {
                    throw RuuviServiceError.ruuviCloud(error)
                }
                do {
                    let localUrl = try await localTask.value
                    localImages.deleteBackgroundUploadProgress(for: mac)
                    return localUrl
                } catch let error as RuuviLocalError {
                    throw RuuviServiceError.ruuviLocal(error)
                }
            } else if let luid {
                do {
                    return try await localImages.setCustomBackground(
                        image: croppedImage,
                        compressionQuality: compressionQuality,
                        for: luid
                    )
                } catch let error as RuuviLocalError {
                    throw RuuviServiceError.ruuviLocal(error)
                }
            } else {
                throw RuuviServiceError.bothLuidAndMacAreNil
            }
        } else {
            if let mac = macId {
                do {
                    return try await localImages.setCustomBackground(
                        image: croppedImage,
                        compressionQuality: compressionQuality,
                        for: mac
                    )
                } catch let error as RuuviLocalError {
                    throw RuuviServiceError.ruuviLocal(error)
                }
            } else if let luid {
                do {
                    return try await localImages.setCustomBackground(
                        image: croppedImage,
                        compressionQuality: compressionQuality,
                        for: luid
                    )
                } catch let error as RuuviLocalError {
                    throw RuuviServiceError.ruuviLocal(error)
                }
            } else {
                throw RuuviServiceError.bothLuidAndMacAreNil
            }
        }
    }

    public func getImage(for sensor: RuuviTagSensor) async throws -> UIImage {
        let dataFormat = RuuviDataFormat.dataFormat(from: sensor.version)
        let ruuviDeviceType: RuuviDeviceType =
            dataFormat == .e1 || dataFormat == .v6 ? .ruuviAir : .ruuviTag
        return try await getImage(
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
            Task { [weak self] in
                _ = try? await self?.resetCloudImage(for: sensor)
            }
        }
    }

    @discardableResult
    public func updateDisplaySettings(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) async throws -> SensorSettings {
        let settings: SensorSettings
        do {
            settings = try await pool.updateDisplaySettings(
                for: sensor,
                displayOrder: displayOrder,
                defaultDisplayOrder: defaultDisplayOrder
            )
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }
        if sensor.isCloud {
            _ = try await pushDisplaySettingsToCloudIfNeeded(
                for: sensor,
                displayOrder: displayOrder,
                defaultDisplayOrder: defaultDisplayOrder
            )
        }
        return settings
    }

    @discardableResult
    private func resetCloudImage(for sensor: RuuviTagSensor) async throws {
        guard let macId = sensor.macId
        else {
            throw RuuviServiceError.macIdIsNil
        }
        do {
            try await cloud.resetImage(for: macId)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    private func getImage(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        ruuviDeviceType: RuuviDeviceType
    ) async throws -> UIImage {
        if let macId {
            if let image = localImages.getBackground(for: macId) {
                return image
            } else if let luid, let image = localImages.getOrGenerateBackground(
                for: luid,
                ruuviDeviceType: ruuviDeviceType
            ) {
                return image
            } else if let image = localImages.getOrGenerateBackground(
                for: macId,
                ruuviDeviceType: ruuviDeviceType
            ) {
                return image
            } else {
                throw RuuviServiceError.failedToFindOrGenerateBackgroundImage
            }
        } else if let luid {
            if let image = localImages.getOrGenerateBackground(
                for: luid,
                ruuviDeviceType: ruuviDeviceType
            ) {
                return image
            } else {
                throw RuuviServiceError.failedToFindOrGenerateBackgroundImage
            }
        } else {
            throw RuuviServiceError.bothLuidAndMacAreNil
        }
    }

    private func pushDisplaySettingsToCloudIfNeeded(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) async throws -> Bool {
        guard sensor.isCloud else { return true }

        var types: [String] = [RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue]
        var values: [String] = [defaultDisplayOrder ? "true" : "false"]

        if let encodedOrder = encodeDisplayOrderForCloud(displayOrder) {
            types.append(RuuviCloudApiSetting.sensorDisplayOrder.rawValue)
            values.append(encodedOrder)
        }

        do {
            _ = try await cloud.updateSensorSettings(
                for: sensor,
                types: types,
                values: values,
                timestamp: Int(Date().timeIntervalSince1970)
            )
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }
        return true
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
