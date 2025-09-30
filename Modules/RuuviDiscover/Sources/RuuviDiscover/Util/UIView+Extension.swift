import UIKit

extension UIButton {
    func setInsets(
        forContentPadding contentPadding: UIEdgeInsets,
        imageTitlePadding: CGFloat
    ) {
        var config = self.configuration ?? .plain()
        config.contentInsets = NSDirectionalEdgeInsets(
            top: contentPadding.top,
            leading: contentPadding.left,
            bottom: contentPadding.bottom,
            trailing: contentPadding.right + imageTitlePadding
        )
        config.imagePadding = imageTitlePadding
        self.configuration = config
    }
}

extension UIView {
    func constraints(to view: UIView, padding: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        [
            topAnchor.constraint(equalTo: view.topAnchor, constant: padding.top),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding.left),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding.bottom),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding.right),
        ]
    }
}
