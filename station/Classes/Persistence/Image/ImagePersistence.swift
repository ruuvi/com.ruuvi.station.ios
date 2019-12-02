import UIKit
import Future

protocol ImagePersistence {
    func fetchBg(for uuid: String) -> UIImage?
    func deleteBgIfExists(for uuid: String)
    func persistBg(image: UIImage, for uuid: String) -> Future<URL, RUError>
}
