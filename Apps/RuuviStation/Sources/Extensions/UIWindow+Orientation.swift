import UIKit

extension UIWindow {
    static var isLandscape: Bool {
        if #available(iOS 13.0, *) {
            UIApplication.shared.windows
                .first?
                .windowScene?
                .interfaceOrientation
                .isLandscape ?? false
        } else {
            UIApplication.shared.statusBarOrientation.isLandscape
        }
    }

    static var isPortrait: Bool {
        !isLandscape
    }

    static var key: UIWindow? {
        if #available(iOS 13, *) {
            UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            UIApplication.shared.keyWindow
        }
    }
}
