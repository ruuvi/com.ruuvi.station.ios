import UIKit

extension UIImage {
    func resize(targetWidth: CGFloat = 100) -> UIImage? {
        let aspectRatio = self.size.width / self.size.height
        let targetHeight = targetWidth / aspectRatio

        let size = CGSize(width: targetWidth, height: targetHeight)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }

    func resize(targetHeight: CGFloat) -> UIImage? {
        let scale = targetHeight / self.size.height
        let newWidth = self.size.width * scale
        let newSize = CGSize(width: newWidth, height: targetHeight)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
