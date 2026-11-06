import Foundation
import RuuviLocal
import RuuviOntology
import UIKit

final class PropertiesImagesSpy: RuuviLocalImages {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    }
    var backgroundChanges = 0
    var cached = [String: UIImage]()
    var generated = [String: UIImage]()
    var requests = [(String, RuuviDeviceType)]()
    var missingDefault = false
    var localFailure: RuuviLocalError?
    var writes = [(String, CGFloat)]()
    var deleted = [String]()
    var invalidated = [String]()
    var progress = [(String, Double)]()
    var deletedProgress = [String]()
    let url = URL(fileURLWithPath: "/offline-test-background.jpg")
    func getOrGenerateBackground(for identifier: Identifier, ruuviDeviceType: RuuviDeviceType) -> UIImage? {
        requests.append((identifier.value, ruuviDeviceType))
        return generated[identifier.value]
    }
    func getBackground(for identifier: Identifier) -> UIImage? { cached[identifier.value] }
    func setBackground(_ id: Int, for identifier: Identifier) {}
    func setNextDefaultBackground(for identifier: Identifier) -> UIImage? {
        backgroundChanges += 1
        return missingDefault ? nil : image
    }
    func getCustomBackground(for identifier: Identifier) -> UIImage? { cached[identifier.value] }
    func setCustomBackground(image: UIImage, compressionQuality: CGFloat, for identifier: Identifier)
        async throws(RuuviLocalError) -> URL
    {
        writes.append((identifier.value, compressionQuality))
        if let localFailure { throw localFailure }
        return url
    }
    func deleteCustomBackground(for uuid: Identifier) { deleted.append(uuid.value) }
    func backgroundUploadProgress(for identifier: Identifier) -> Double? { progress.last?.1 }
    func setBackgroundUploadProgress(percentage: Double, for identifier: Identifier) {
        progress.append((identifier.value, percentage))
    }
    func deleteBackgroundUploadProgress(for identifier: Identifier) { deletedProgress.append(identifier.value) }
    func isPictureCached(for cloudSensor: CloudSensor) -> Bool { false }
    func setPictureIsCached(for cloudSensor: CloudSensor) {}
    func setPictureRemovedFromCache(for ruuviTag: RuuviTagSensor) { invalidated.append(ruuviTag.id) }
}
