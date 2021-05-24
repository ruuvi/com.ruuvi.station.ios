import UIKit

protocol ImageCoreService {
    func cropped(image: UIImage, to maxSize: CGSize) -> UIImage
}
