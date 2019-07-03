import UIKit

extension Notification.Name {
    static let BackgroundPersistenceDidChangeBackground = Notification.Name("BackgroundPersistenceDidChangeBackground")
}

enum BackgroundPersistenceDidChangeBackgroundKey: String {
    case uuid = "uuid"
}

protocol BackgroundPersistence {
    func background(for uuid: String) -> UIImage?
    func setBackground(_ id: Int, for uuid: String)
    func setNextBackground(for uuid: String) -> UIImage?
}
