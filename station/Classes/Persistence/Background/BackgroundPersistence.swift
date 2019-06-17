import UIKit

protocol BackgroundPersistence {
    func background(for uuid: String) -> UIImage?
}
