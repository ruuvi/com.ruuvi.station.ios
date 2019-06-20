import UIKit

protocol BackgroundPersistence {
    func background(for uuid: String) -> UIImage?
    func setBackground(_ id: Int, for uuid: String)
}
