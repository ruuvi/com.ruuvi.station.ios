import UIKit
import Future

extension Notification.Name {
    static let BackgroundPersistenceDidChangeBackground = Notification.Name("BackgroundPersistenceDidChangeBackground")
}

enum BPDidChangeBackgroundKey: String {
    case luid // LocalIdenfitier
    case macId
}

protocol BackgroundPersistence {
    func background(for identifier: Identifier) -> UIImage?
    func setBackground(_ id: Int, for identifier: Identifier)
    func setNextDefaultBackground(for identifier: Identifier) -> UIImage?
    func setCustomBackground(image: UIImage, for identifier: Identifier) -> Future<URL, RUError>
    func deleteCustomBackground(for uuid: Identifier)
}
