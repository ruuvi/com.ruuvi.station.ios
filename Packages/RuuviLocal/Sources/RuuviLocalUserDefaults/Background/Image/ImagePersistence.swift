import UIKit
import Future
import RuuviOntology
import RuuviLocal

protocol ImagePersistence {
    func fetchBg(for identifier: Identifier) -> UIImage?
    func deleteBgIfExists(for identifier: Identifier)
    func persistBg(image: UIImage, for identifier: Identifier) -> Future<URL, RuuviLocalError>
}
