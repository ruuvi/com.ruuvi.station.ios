import UIKit

public protocol RuuviCoreImage {
    func cropped(image: UIImage, to maxSize: CGSize) -> UIImage
}
