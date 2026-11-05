import Foundation
import RuuviOntology
import RuuviService
import UIKit

@MainActor final class AppSensorPropertiesSpy: RuuviServiceSensorProperties {
    var imageWrites = [(String, UIImage, CGSize, CGFloat)]()
    var beforeSetImage: (() async -> Void)?
    var images = [String: UIImage]()
    var imageReads = [String]()
    var names = [(String, String)]()
    var beforeImage: (() async -> Void)?
    var beforeName: (() async -> Void)?
    var failure: RuuviServiceError?
    func set(name: String, for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> AnyRuuviTagSensor {
        names.append((sensor.id, name))
        await beforeName?()
        if let failure { throw failure }
        return sensor.with(name: name).any
    }
    func getImage(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage {
        imageReads.append(sensor.id)
        let image = images[sensor.id]
        await beforeImage?()
        if let failure { throw failure }
        guard let image else { throw .failedToGetJpegRepresentation }
        return image
    }
    func set(
        image: UIImage, for sensor: RuuviTagSensor, progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize, compressionQuality: CGFloat
    ) async throws(RuuviServiceError) -> URL {
        imageWrites.append((sensor.id, image, maxSize, compressionQuality))
        await beforeSetImage?()
        if let failure { throw failure }
        return URL(fileURLWithPath: "/test-background.jpg")
    }
    func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage {
        throw .failedToGetJpegRepresentation
    }
    func removeImage(for sensor: RuuviTagSensor) { images.removeValue(forKey: sensor.id) }
    func updateDisplaySettings(for sensor: RuuviTagSensor, displayOrder: [String]?, defaultDisplayOrder: Bool)
        async throws(RuuviServiceError) -> SensorSettings
    { throw .failedToParseNetworkResponse }
    func updateDescription(for sensor: RuuviTagSensor, description: String?)
        async throws(RuuviServiceError) -> SensorSettings
    { throw .failedToParseNetworkResponse }
}
