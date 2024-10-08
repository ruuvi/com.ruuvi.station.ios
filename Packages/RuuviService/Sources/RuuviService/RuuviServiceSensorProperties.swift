import Foundation
import Future
import RuuviOntology
import UIKit

public protocol RuuviServiceSensorProperties {
    @discardableResult
    func set(
        name: String,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) -> Future<URL, RuuviServiceError>

    @discardableResult
    func setNextDefaultBackground(for sensor: RuuviTagSensor) -> Future<UIImage, RuuviServiceError>

    func getImage(for sensor: RuuviTagSensor) -> Future<UIImage, RuuviServiceError>

    func removeImage(for sensor: RuuviTagSensor)
}

public extension RuuviServiceSensorProperties {
    func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) -> Future<URL, RuuviServiceError> {
        set(
            image: image,
            for: sensor,
            progress: nil,
            maxSize: maxSize,
            compressionQuality: compressionQuality
        )
    }
}
