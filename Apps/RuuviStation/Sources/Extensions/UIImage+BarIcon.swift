import UIKit

extension UIImage {
    /// Scales an icon asset (aspect fit, centered) to a square canvas sized like a standard bar
    /// button symbol and returns it as a template image. Used for iPhone Duo vertical bar items,
    /// whose assets are drawn for larger custom buttons.
    func ruuviBarIcon(pointSize: CGFloat = 28) -> UIImage {
        guard size.width > 0, size.height > 0 else { return withRenderingMode(.alwaysTemplate) }
        let canvas = CGSize(width: pointSize, height: pointSize)
        let ratio = min(canvas.width / size.width, canvas.height / size.height)
        let drawSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let origin = CGPoint(
            x: (canvas.width - drawSize.width) / 2,
            y: (canvas.height - drawSize.height) / 2
        )
        let image = UIGraphicsImageRenderer(size: canvas).image { _ in
            draw(in: CGRect(origin: origin, size: drawSize))
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
