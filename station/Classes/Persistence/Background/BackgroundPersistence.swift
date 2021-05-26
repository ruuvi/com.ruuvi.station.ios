import UIKit
import Future
import RuuviOntology

extension Notification.Name {
    static let BackgroundPersistenceDidChangeBackground = Notification.Name("BackgroundPersistenceDidChangeBackground")
    static let BackgroundPersistenceDidUpdateBackgroundUploadProgress
        = Notification.Name("BackgroundPersistenceDidUpdateBackgroundUploadProgress")
}

enum BPDidChangeBackgroundKey: String {
    case luid // LocalIdenfitier
    case macId
}

enum BPDidUpdateBackgroundUploadProgressKey: String {
    case luid // LocalIdenfitier
    case macId
    case progress
}

protocol BackgroundPersistence {
    func background(for identifier: Identifier) -> UIImage?
    func setBackground(_ id: Int, for identifier: Identifier)
    func setNextDefaultBackground(for identifier: Identifier) -> UIImage?
    func setCustomBackground(image: UIImage, for identifier: Identifier) -> Future<URL, RUError>
    func deleteCustomBackground(for uuid: Identifier)

    func backgroundUploadProgress(for identifier: Identifier) -> Double?
    func setBackgroundUploadProgress(percentage: Double, for identifier: Identifier)
    func deleteBackgroundUploadProgress(for identifier: Identifier)
}
