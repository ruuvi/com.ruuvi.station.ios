import UIKit
import Future

extension Notification.Name {
    static let BackgroundPersistenceDidChangeBackground = Notification.Name("BackgroundPersistenceDidChangeBackground")
}

enum BPDidChangeBackgroundKey: String {
    case luid // LocalIdenfitier
}

protocol BackgroundPersistence {
    func background(for luid: LocalIdentifier) -> UIImage?
    func setBackground(_ id: Int, for luid: LocalIdentifier)
    func setNextDefaultBackground(for luid: LocalIdentifier) -> UIImage?
    func setCustomBackground(image: UIImage, for luid: LocalIdentifier) -> Future<URL, RUError>
    func deleteCustomBackground(for uuid: LocalIdentifier)
}
