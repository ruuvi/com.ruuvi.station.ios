import Foundation
import RuuviCloud
import RuuviCore
import RuuviLocal
import RuuviOntology
import RuuviPool
import UIKit

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
            try await pool.update(namedSensor)
            if sensor.isCloud {
                // fire-and-forget cloud update (legacy behavior) - ignore errors
                try? await cloud.update(name: name, for: sensor)
            }
            return namedSensor.any
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        } catch {
            throw RuuviServiceError.unknown(error)
        }
    }

    public func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws -> UIImage {
        let luid = sensor.luid
        let macId = sensor.macId
        if sensor.isCloud {
            try? await resetCloudImage(for: sensor)
        }
        return try await setNextDefaultBackground(luid: luid, macId: macId)
    }

    private func setNextDefaultBackground(
        luid: LocalIdentifier?,
        macId: MACIdentifier?
    ) async throws -> UIImage {
        let identifier = macId ?? luid
        guard let identifier else { throw RuuviServiceError.bothLuidAndMacAreNil }
        if let image = localImages.setNextDefaultBackground(for: identifier) {
            return image
        } else {
            throw RuuviServiceError.failedToFindOrGenerateBackgroundImage
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
        guard let jpegData = croppedImage.jpegData(compressionQuality: compressionQuality) else {
            throw RuuviServiceError.failedToGetJpegRepresentation
        }
        let luid = sensor.luid
        let macId = sensor.macId
        assert(luid != nil || macId != nil)

        // For local operations we assume localImages APIs become synchronous (they currently return Future). We provide async wrappers.
        func setCustomBackground(for identifier: Any) async throws -> URL {
            if let mac = identifier as? MACIdentifier {
                do { return try await localImages.setCustomBackground(image: croppedImage, compressionQuality: compressionQuality, for: mac) }
                catch let error as RuuviLocalError { throw RuuviServiceError.ruuviLocal(error) }
            } else if let luid = identifier as? LocalIdentifier {
                do { return try await localImages.setCustomBackground(image: croppedImage, compressionQuality: compressionQuality, for: luid) }
                catch let error as RuuviLocalError { throw RuuviServiceError.ruuviLocal(error) }
            } else { throw RuuviServiceError.bothLuidAndMacAreNil }
        }

        if sensor.isCloud {
            if let mac = macId {
                localImages.setBackgroundUploadProgress(percentage: 0.0, for: mac)
                let remoteUploadTask = Task { () throws -> Void in
                    do {
                        _ = try await cloud.upload(
                            imageData: jpegData,
                            mimeType: .jpg,
                            progress: { macId, percentage in
                                self.localImages.setBackgroundUploadProgress(percentage: percentage, for: macId)
                                progress?(macId, percentage)
                            },
                            for: mac
                        )
                    } catch let error as RuuviCloudError {
                        throw RuuviServiceError.ruuviCloud(error)
                    }
                }
                do {
                    let localURL = try await setCustomBackground(for: mac)
                    // await remote completion
                    _ = try await remoteUploadTask.value
                    self.localImages.deleteBackgroundUploadProgress(for: mac)
                    return localURL
                } catch {
                    if let mac = macId { self.localImages.deleteBackgroundUploadProgress(for: mac) }
                    throw error
                }
            } else if let luid {
                return try await setCustomBackground(for: luid)
            } else {
                throw RuuviServiceError.bothLuidAndMacAreNil
            }
        } else {
            if let mac = macId {
                return try await setCustomBackground(for: mac)
            } else if let luid {
                return try await setCustomBackground(for: luid)
            } else {
                throw RuuviServiceError.bothLuidAndMacAreNil
            }
        }
    }

    public func getImage(for sensor: RuuviTagSensor) async throws -> UIImage {
        try await getImage(luid: sensor.luid, macId: sensor.macId)
    }

    public func removeImage(for sensor: RuuviTagSensor) async {
        if let macId = sensor.macId {
            localImages.deleteCustomBackground(for: macId)
        }
        if let luid = sensor.luid {
            localImages.deleteCustomBackground(for: luid)
        }
        localImages.setPictureRemovedFromCache(for: sensor)
        if sensor.isCloud {
            try? await resetCloudImage(for: sensor)
        }
    }

    @discardableResult
    private func resetCloudImage(for sensor: RuuviTagSensor) async throws -> Void {
        guard let macId = sensor.macId else { throw RuuviServiceError.macIdIsNil }
        do {
            try await cloud.resetImage(for: macId)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        } catch {
            throw RuuviServiceError.unknown(error)
        }
    }

    private func getImage(luid: LocalIdentifier?, macId: MACIdentifier?) async throws -> UIImage {
        if let macId {
            if let image = localImages.getBackground(for: macId) {
                return image
            } else if let luid, let image = localImages.getOrGenerateBackground(for: luid) {
                return image
            } else if let image = localImages.getOrGenerateBackground(for: macId) {
                return image
            } else {
                throw RuuviServiceError.failedToFindOrGenerateBackgroundImage
            }
        } else if let luid {
            if let image = localImages.getOrGenerateBackground(for: luid) {
                return image
            } else {
                throw RuuviServiceError.failedToFindOrGenerateBackgroundImage
            }
        } else {
            throw RuuviServiceError.bothLuidAndMacAreNil
        }
    }
}
