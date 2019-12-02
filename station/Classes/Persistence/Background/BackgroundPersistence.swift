import UIKit
import Future

extension Notification.Name {
    static let BackgroundPersistenceDidChangeBackground = Notification.Name("BackgroundPersistenceDidChangeBackground")
}

enum BPDidChangeBackgroundKey: String {
    case uuid
}

protocol BackgroundPersistence {
    func background(for uuid: String) -> UIImage?
    func setBackground(_ id: Int, for uuid: String)
    func setNextDefaultBackground(for uuid: String) -> UIImage?
    func setCustomBackground(image: UIImage, for uuid: String) -> Future<URL, RUError>
    func deleteCustomBackground(for uuid: String)
}
