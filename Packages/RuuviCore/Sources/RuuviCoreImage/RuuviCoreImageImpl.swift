import AVFoundation
import CoreGraphics
import Foundation
import UIKit

public final class RuuviCoreImageImpl: RuuviCoreImage {
    public init() {}

    public func cropped(image: UIImage, to maxSize: CGSize) -> UIImage {
        if image.size.width > maxSize.width || image.size.height > maxSize.height {
            let boundingRect = CGRect(origin: CGPoint(x: 0, y: 0), size: maxSize)
            let croppedRect = AVMakeRect(aspectRatio: image.size, insideRect: boundingRect)
            return image.ruuviCoreImageAspectScaled(toFit: croppedRect.size)
        } else {
            return image
        }
    }
}

extension UIImage {
    func ruuviCoreImageAspectScaled(toFit size: CGSize) -> UIImage {
        assert(size.width > 0 && size.height > 0, "You cannot safely scale an image to a zero width or height")

        let imageAspectRatio = self.size.width / self.size.height
        let canvasAspectRatio = size.width / size.height

        let resizeFactor: CGFloat = if imageAspectRatio > canvasAspectRatio {
            size.width / self.size.width
        } else {
            size.height / self.size.height
        }

        let scaledSize = CGSize(width: self.size.width * resizeFactor, height: self.size.height * resizeFactor)
        let origin = CGPoint(x: (size.width - scaledSize.width) / 2.0, y: (size.height - scaledSize.height) / 2.0)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        draw(in: CGRect(origin: origin, size: scaledSize))

        let scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()

        return scaledImage
    }
}
