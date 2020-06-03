import UIKit
import Future

protocol ImagePersistence {
    func fetchBg(for luid: LocalIdentifier) -> UIImage?
    func deleteBgIfExists(for luid: LocalIdentifier)
    func persistBg(image: UIImage, for luid: LocalIdentifier) -> Future<URL, RUError>
}
