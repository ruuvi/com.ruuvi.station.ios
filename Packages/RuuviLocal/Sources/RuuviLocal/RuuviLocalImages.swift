import UIKit
import Future
import RuuviOntology

extension Notification.Name {
    public static let BackgroundPersistenceDidChangeBackground
        = Notification.Name("BackgroundPersistenceDidChangeBackground")
    public static let BackgroundPersistenceDidUpdateBackgroundUploadProgress
        = Notification.Name("BackgroundPersistenceDidUpdateBackgroundUploadProgress")
}

public enum BPDidChangeBackgroundKey: String {
    case luid // LocalIdenfitier
    case macId
}

public enum BPDidUpdateBackgroundUploadProgressKey: String {
    case luid // LocalIdenfitier
    case macId
    case progress
}

public protocol RuuviLocalImages {
    func getOrGenerateBackground(for identifier: Identifier) -> UIImage?
    func getBackground(for identifier: Identifier) -> UIImage?
    func setBackground(_ id: Int, for identifier: Identifier)
    func setNextDefaultBackground(for identifier: Identifier) -> UIImage?
    func setCustomBackground(image: UIImage, for identifier: Identifier) -> Future<URL, RuuviLocalError>
    func deleteCustomBackground(for uuid: Identifier)

    func backgroundUploadProgress(for identifier: Identifier) -> Double?
    func setBackgroundUploadProgress(percentage: Double, for identifier: Identifier)
    func deleteBackgroundUploadProgress(for identifier: Identifier)

    func isPictureCached(for cloudSensor: CloudSensor) -> Bool
    func setPictureIsCached(for cloudSensor: CloudSensor)
}
