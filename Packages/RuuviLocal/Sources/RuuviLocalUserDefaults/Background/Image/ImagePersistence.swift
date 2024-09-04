import Future
import RuuviOntology
import UIKit

protocol ImagePersistence {
    func fetchBg(for identifier: Identifier) -> UIImage?
    func deleteBgIfExists(for identifier: Identifier)
    func persistBg(
        image: UIImage,
        compressionQuality: CGFloat,
        for identifier: Identifier
    ) -> Future<URL, RuuviLocalError>
}
