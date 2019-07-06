import UIKit
import Future

protocol ImagePersistence {
    func fetch(uuid: String) -> UIImage?
    func delete(uuid: String)
    func persist(image: UIImage, for uuid: String) -> Future<URL,RUError>
}
