import UIKit

extension UIWindow {
    static var isLandscape: Bool {
        key?.windowScene?
            .interfaceOrientation
            .isLandscape ?? false
    }

    static var isPortrait: Bool {
        !isLandscape
    }

    static var key: UIWindow? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let activeScene = windowScenes
            .filter { $0.activationState == .foregroundActive }
        let firstActiveScene = activeScene.first
        let keyWindow = firstActiveScene?.keyWindow
        return keyWindow
    }
}
