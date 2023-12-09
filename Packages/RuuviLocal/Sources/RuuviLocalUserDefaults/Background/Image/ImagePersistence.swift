import Future
import RuuviLocal
import RuuviOntology
import UIKit

protocol ImagePersistence {
    func fetchBg(for identifier: Identifier) -> UIImage?
    func deleteBgIfExists(for identifier: Identifier)
    func persistBg(image: UIImage, for identifier: Identifier) -> Future<URL, RuuviLocalError>
}
