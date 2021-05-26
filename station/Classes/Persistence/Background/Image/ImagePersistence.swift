import UIKit
import Future
import RuuviOntology

protocol ImagePersistence {
    func fetchBg(for identifier: Identifier) -> UIImage?
    func deleteBgIfExists(for identifier: Identifier)
    func persistBg(image: UIImage, for identifier: Identifier) -> Future<URL, RUError>
}
