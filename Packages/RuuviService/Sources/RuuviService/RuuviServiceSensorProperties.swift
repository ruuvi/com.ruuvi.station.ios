import Foundation
import RuuviOntology
import UIKit

public protocol RuuviServiceSensorProperties {
    @discardableResult
    func set(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor

    @discardableResult
    func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) async throws -> URL

    @discardableResult
    func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws -> UIImage

    func getImage(for sensor: RuuviTagSensor) async throws -> UIImage

    func removeImage(for sensor: RuuviTagSensor) async
}

public extension RuuviServiceSensorProperties {
    func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) async throws -> URL {
        try await set(
            image: image,
            for: sensor,
            progress: nil,
            maxSize: maxSize,
            compressionQuality: compressionQuality
        )
    }
}
