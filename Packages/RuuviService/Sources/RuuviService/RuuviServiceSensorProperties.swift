#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviCloud
    import RuuviPool
    import RuuviLocal
    import RuuviRepository
    import RuuviCore
#endif
import Foundation
import RuuviOntology
import UIKit

public protocol RuuviServiceSensorProperties {
    @discardableResult
    func set(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws(RuuviServiceError) -> AnyRuuviTagSensor

    @discardableResult
    func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) async throws(RuuviServiceError) -> URL

    @discardableResult
    func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage

    func getImage(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage

    func removeImage(for sensor: RuuviTagSensor)

    @discardableResult
    func updateDisplaySettings(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) async throws(RuuviServiceError) -> SensorSettings

    @discardableResult
    func updateDescription(
        for sensor: RuuviTagSensor,
        description: String?
    ) async throws(RuuviServiceError) -> SensorSettings
}

public extension RuuviServiceSensorProperties {
    func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) async throws(RuuviServiceError) -> URL {
        try await set(
            image: image,
            for: sensor,
            progress: nil,
            maxSize: maxSize,
            compressionQuality: compressionQuality
        )
    }
}
