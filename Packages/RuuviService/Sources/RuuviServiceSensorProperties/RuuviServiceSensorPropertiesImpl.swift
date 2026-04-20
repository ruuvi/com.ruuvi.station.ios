// swiftlint:disable file_length
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
        let updatedSensor = sensor.with(name: name).with(lastUpdated: Date())
        return try await RuuviServiceError.perform {
            _ = try await self.pool.update(updatedSensor)
            if sensor.isCloud {
                Task {
                    _ = try? await self.cloud.update(name: name, for: sensor)
                }
            }
            return updatedSensor.any
        }
    }

    public func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws -> UIImage {
        let luid = sensor.luid
        let macId = sensor.macId
        if sensor.isCloud {
            Task {
                try? await self.resetCloudImage(for: sensor)
            }
        }
        let image = try await setNextDefaultBackground(luid: luid, macId: macId)
        updateSensorTimestamp(for: sensor)
        return image
    }

    public func setNextDefaultBackground(
        luid: LocalIdentifier?,
        macId: MACIdentifier?
    ) async throws -> UIImage {
        let identifier = macId ?? luid
        guard let identifier else {
            throw RuuviServiceError.bothLuidAndMacAreNil
        }
        guard let image = localImages.setNextDefaultBackground(for: identifier) else {
            throw RuuviServiceError.failedToFindOrGenerateBackgroundImage
        }
        return image
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
        guard let jpegData = croppedImage.jpegData(compressionQuality: compressionQuality) else {
            throw RuuviServiceError.failedToGetJpegRepresentation
        }
        let luid = sensor.luid
        let macId = sensor.macId
        guard let identifier = macId ?? luid else {
            throw RuuviServiceError.bothLuidAndMacAreNil
        }

        if sensor.isCloud, let mac = macId {
            localImages.setBackgroundUploadProgress(percentage: 0.0, for: mac)
            let localUrl = try await RuuviServiceError.perform {
                try await self.localImages.setCustomBackground(
                    image: croppedImage,
                    compressionQuality: compressionQuality,
                    for: mac
                )
            }
            updateSensorTimestamp(for: sensor)
            do {
                _ = try await RuuviServiceError.perform {
                    try await self.cloud.upload(
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
                localImages.deleteBackgroundUploadProgress(for: mac)
                return localUrl
            } catch {
                localImages.deleteBackgroundUploadProgress(for: mac)
                throw error
            }
        }

        let localUrl = try await RuuviServiceError.perform {
            try await self.localImages.setCustomBackground(
                image: croppedImage,
                compressionQuality: compressionQuality,
                for: identifier
            )
        }
        updateSensorTimestamp(for: sensor)
        return localUrl
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
        updateSensorTimestamp(for: sensor)
        if sensor.isCloud {
            Task {
                try? await self.resetCloudImage(for: sensor)
            }
        }
    }

    @discardableResult
    // swiftlint:disable:next function_body_length
    public func updateDisplaySettings(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) async throws -> SensorSettings {
        let updatedAt = Date()
        return try await RuuviServiceError.perform {
            let currentSettings = try await self.pool.readSensorSettings(sensor)

            var displayOrderTimestamp: Date?
            var defaultDisplayOrderTimestamp: Date?

            if let currentDisplayOrder = currentSettings?.displayOrder,
               let newDisplayOrder = displayOrder {
                if currentDisplayOrder != newDisplayOrder {
                    displayOrderTimestamp = updatedAt
                }
            } else if displayOrder != nil {
                displayOrderTimestamp = updatedAt
            }

            if let currentDefaultDisplayOrder = currentSettings?.defaultDisplayOrder {
                if currentDefaultDisplayOrder != defaultDisplayOrder {
                    defaultDisplayOrderTimestamp = updatedAt
                }
            } else {
                defaultDisplayOrderTimestamp = updatedAt
            }

            let settings = try await self.pool.updateDisplaySettings(
                for: sensor,
                displayOrder: displayOrder,
                defaultDisplayOrder: defaultDisplayOrder,
                displayOrderLastUpdated: displayOrderTimestamp,
                defaultDisplayOrderLastUpdated: defaultDisplayOrderTimestamp
            )

            if sensor.isCloud {
                try await self.pushDisplaySettingsToCloudIfNeeded(
                    for: sensor,
                    displayOrder: displayOrder,
                    defaultDisplayOrder: defaultDisplayOrder
                )
            }

            return settings
        }
    }

    @discardableResult
    public func updateDescription(
        for sensor: RuuviTagSensor,
        description: String?
    ) async throws -> SensorSettings {
        let updatedAt = Date()
        return try await RuuviServiceError.perform {
            let currentSettings = try await self.pool.readSensorSettings(sensor)
            let descriptionTimestamp: Date? =
                currentSettings?.description != description ? updatedAt : nil

            let settings = try await self.pool.updateDescription(
                for: sensor,
                description: description,
                descriptionLastUpdated: descriptionTimestamp
            )

            if sensor.isCloud {
                try await self.pushDescriptionToCloudIfNeeded(
                    for: sensor,
                    description: description
                )
            }

            return settings
        }
    }

    private func resetCloudImage(for sensor: RuuviTagSensor) async throws {
        guard let macId = sensor.macId else {
            throw RuuviServiceError.macIdIsNil
        }
        _ = try await RuuviServiceError.perform {
            try await self.cloud.resetImage(for: macId)
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
    ) async throws {
        guard sensor.isCloud else { return }

        var types: [String] = [RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue]
        var values: [String] = [defaultDisplayOrder ? "true" : "false"]

        if let encodedOrder = encodeDisplayOrderForCloud(displayOrder) {
            types.append(RuuviCloudApiSetting.sensorDisplayOrder.rawValue)
            values.append(encodedOrder)
        }

        _ = try await RuuviServiceError.perform {
            try await self.cloud.updateSensorSettings(
                for: sensor,
                types: types,
                values: values,
                timestamp: Int(Date().timeIntervalSince1970)
            )
        }
    }

    private func pushDescriptionToCloudIfNeeded(
        for sensor: RuuviTagSensor,
        description: String?
    ) async throws {
        guard sensor.isCloud else { return }

        _ = try await RuuviServiceError.perform {
            try await self.cloud.updateSensorSettings(
                for: sensor,
                types: [RuuviCloudApiSetting.sensorDescription.rawValue],
                values: [description ?? ""],
                timestamp: Int(Date().timeIntervalSince1970)
            )
        }
    }

    private func encodeDisplayOrderForCloud(_ codes: [String]?) -> String? {
        guard let codes, !codes.isEmpty else {
            return nil
        }
        return String(data: try! JSONEncoder().encode(codes), encoding: .utf8)!
    }

    private func updateSensorTimestamp(for sensor: RuuviTagSensor) {
        let updatedSensor = sensor.with(lastUpdated: Date())
        Task {
            _ = try? await self.pool.update(updatedSensor)
        }
    }
}

// swiftlint:enable file_length
