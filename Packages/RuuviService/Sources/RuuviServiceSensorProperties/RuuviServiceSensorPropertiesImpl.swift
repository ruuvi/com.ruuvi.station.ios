#if SWIFT_PACKAGE
    import RuuviService
    import RuuviCloudApi
#endif
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
    private let backgroundTasks = RuuviTaskStore()

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

    @MainActor
    public func set(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws(RuuviServiceError) -> AnyRuuviTagSensor {
        let updatedSensor = sensor.with(name: name).with(lastUpdated: Date())
        do { _ = try await pool.update(updatedSensor) } catch { throw .ruuviPool(error) }
        if sensor.isCloud {
            backgroundTasks.run(seriallyFor: "name:" + sensor.id) { @MainActor [cloud] in
                _ = try? await cloud.update(name: name, for: sensor)
            }
        }
        return updatedSensor.any
    }

    @MainActor
    public func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage {
        let image = try await setNextDefaultBackground(luid: sensor.luid, macId: sensor.macId)
        await updateSensorTimestamp(for: sensor)
        if sensor.isCloud {
            backgroundTasks.run(seriallyFor: "image:" + sensor.id) { @MainActor [self] in
                _ = try? await resetCloudImage(for: sensor)
            }
        }
        return image
    }

    @MainActor
    public func setNextDefaultBackground(
        luid: LocalIdentifier?,
        macId: MACIdentifier?
    ) async throws(RuuviServiceError) -> UIImage {
        var outcome: Result<UIImage, RuuviServiceError>
        let identifier = macId ?? luid
        if let identifier {
            if let image = localImages.setNextDefaultBackground(for: identifier) {
                outcome = .success(image)
            } else {
                outcome = .failure(.failedToFindOrGenerateBackgroundImage)
            }
        } else {
            outcome = .failure(.bothLuidAndMacAreNil)
        }
        return try outcome.get()
    }

    @MainActor
    public func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) async throws(RuuviServiceError) -> URL {
        let image = coreImage.cropped(image: image, to: maxSize)
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw .failedToGetJpegRepresentation
        }
        guard let identifier = sensor.macId ?? sensor.luid else { throw .bothLuidAndMacAreNil }
        let localURL: URL
        do {
            localURL = try await localImages.setCustomBackground(
                image: image, compressionQuality: compressionQuality, for: identifier
            )
        } catch { throw .ruuviLocal(error) }
        await updateSensorTimestamp(for: sensor)
        if sensor.isCloud, let mac = sensor.macId {
            localImages.setBackgroundUploadProgress(percentage: 0, for: mac)
            defer { localImages.deleteBackgroundUploadProgress(for: mac) }
            do {
                _ = try await cloud.upload(
                    imageData: data, mimeType: .jpg,
                    progress: { [localImages] mac, percentage in
                        localImages.setBackgroundUploadProgress(percentage: percentage, for: mac)
                        progress?(mac, percentage)
                    }, for: mac)
            } catch { throw .ruuviCloud(error) }
        }
        return localURL
    }

    @MainActor
    public func getImage(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage {
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
        backgroundTasks.run { @MainActor [self] in
            await updateSensorTimestamp(for: sensor)
            if sensor.isCloud { _ = try? await resetCloudImage(for: sensor) }
        }
    }

    @discardableResult
    @MainActor
    // swiftlint:disable:next function_body_length
    public func updateDisplaySettings(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) async throws(RuuviServiceError) -> SensorSettings {
        var outcome: Result<SensorSettings, RuuviServiceError>
        let updatedAt = Date()

        // Fetch current settings to determine which timestamps to update
        do {
            let currentSettings = try await pool.readSensorSettings(sensor)
            let displayOrderTimestamp = currentSettings?.displayOrder != displayOrder
                ? updatedAt : currentSettings?.displayOrderLastUpdated
            let defaultDisplayOrderTimestamp = currentSettings?.defaultDisplayOrder != defaultDisplayOrder
                ? updatedAt : currentSettings?.defaultDisplayOrderLastUpdated

            do {
                let settings = try await self.pool.updateDisplaySettings(
                    for: sensor,
                    displayOrder: displayOrder,
                    defaultDisplayOrder: defaultDisplayOrder,
                    displayOrderLastUpdated: displayOrderTimestamp,
                    defaultDisplayOrderLastUpdated: defaultDisplayOrderTimestamp
                )
                if sensor.isCloud {
                    do {
                        let _ = try await self.pushDisplaySettingsToCloudIfNeeded(
                            for: sensor,
                            displayOrder: displayOrder,
                            defaultDisplayOrder: defaultDisplayOrder
                        )
                        outcome = .success(settings)
                    } catch let error {
                        outcome = .failure(error)
                    }
                } else {
                    outcome = .success(settings)
                }
            } catch let error {
                outcome = .failure(.ruuviPool(error))
            }
        } catch let error {
            outcome = .failure(.ruuviPool(error))
        }

        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func updateDescription(
        for sensor: RuuviTagSensor,
        description: String?
    ) async throws(RuuviServiceError) -> SensorSettings {
        var outcome: Result<SensorSettings, RuuviServiceError>
        let updatedAt = Date()

        do {
            let currentSettings = try await pool.readSensorSettings(sensor)
            let descriptionTimestamp: Date? =
                currentSettings?.description != description ? updatedAt : currentSettings?.descriptionLastUpdated

            do {
                let settings = try await self.pool.updateDescription(
                    for: sensor,
                    description: description,
                    descriptionLastUpdated: descriptionTimestamp
                )
                if sensor.isCloud {
                    do {
                        let _ = try await self.pushDescriptionToCloudIfNeeded(
                            for: sensor,
                            description: description
                        )
                        outcome = .success(settings)
                    } catch let error {
                        outcome = .failure(error)
                    }
                } else {
                    outcome = .success(settings)
                }
            } catch let error {
                outcome = .failure(.ruuviPool(error))
            }
        } catch let error {
            outcome = .failure(.ruuviPool(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    private func resetCloudImage(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> Void {
        var outcome: Result<Void, RuuviServiceError>
        guard let macId = sensor.macId
        else {
            outcome = .failure(.macIdIsNil)
            return try outcome.get()
        }
        do {
            let _ = try await cloud.resetImage(for: macId)
            outcome = .success(())
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @MainActor
    private func getImage(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        ruuviDeviceType: RuuviDeviceType
    ) async throws(RuuviServiceError) -> UIImage {
        var outcome: Result<UIImage, RuuviServiceError>
        if let macId {
            if let image = localImages.getBackground(for: macId) {
                outcome = .success(image)
            } else if let luid,
                let image = localImages.getOrGenerateBackground(
                    for: luid,
                    ruuviDeviceType: ruuviDeviceType
                )
            {
                outcome = .success(image)
            } else if let image = localImages.getOrGenerateBackground(
                for: macId,
                ruuviDeviceType: ruuviDeviceType
            ) {
                outcome = .success(image)
            } else {
                outcome = .failure(.failedToFindOrGenerateBackgroundImage)
            }
        } else if let luid {
            if let image = localImages.getOrGenerateBackground(
                for: luid,
                ruuviDeviceType: ruuviDeviceType
            ) {
                outcome = .success(image)
            } else {
                outcome = .failure(.failedToFindOrGenerateBackgroundImage)
            }
        } else {
            outcome = .failure(.bothLuidAndMacAreNil)
        }
        return try outcome.get()
    }

    @MainActor
    private func pushDisplaySettingsToCloudIfNeeded(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>

        guard sensor.isCloud else { return false }

        var types: [String] = [RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue]
        var values: [String] = [defaultDisplayOrder ? "true" : "false"]

        if let encodedOrder = encodeDisplayOrderForCloud(displayOrder) {
            types.append(RuuviCloudApiSetting.sensorDisplayOrder.rawValue)
            values.append(encodedOrder)
        }

        do {
            let _ = try await cloud.updateSensorSettings(
                for: sensor,
                types: types,
                values: values,
                timestamp: Int(Date().timeIntervalSince1970)
            )
            outcome = .success(true)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }

        return try outcome.get()
    }

    @MainActor
    private func pushDescriptionToCloudIfNeeded(
        for sensor: RuuviTagSensor,
        description: String?
    ) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>
        guard sensor.isCloud else { return false }

        do {
            let _ = try await cloud.updateSensorSettings(
                for: sensor,
                types: [RuuviCloudApiSetting.sensorDescription.rawValue],
                values: [description ?? ""],
                timestamp: Int(Date().timeIntervalSince1970)
            )
            outcome = .success(true)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }

        return try outcome.get()
    }

    private func encodeDisplayOrderForCloud(_ codes: [String]?) -> String? {
        guard let codes, !codes.isEmpty else {
            return nil
        }
        if let data = try? JSONEncoder().encode(codes),
            let string = String(data: data, encoding: .utf8)
        {
            return string
        }
        if let data = try? JSONSerialization.data(withJSONObject: codes, options: []),
            let string = String(data: data, encoding: .utf8)
        {
            return string
        }
        return nil
    }

    @MainActor
    private func updateSensorTimestamp(for sensor: RuuviTagSensor) async {
        let updatedSensor = sensor.with(lastUpdated: Date())
        _ = try? await pool.update(updatedSensor)
    }
}
