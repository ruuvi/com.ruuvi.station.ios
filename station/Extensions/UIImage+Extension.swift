import UIKit

extension Optional where Wrapped == UIImage {
    func resize(targetWidth: CGFloat = 100) -> UIImage? {
        guard let self = self else {
            return nil
        }

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
        guard let self = self else {
            return nil
        }

        let scale = targetHeight / self.size.height
        let newWidth = self.size.width * scale
        let newSize = CGSize(width: newWidth, height: targetHeight)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
