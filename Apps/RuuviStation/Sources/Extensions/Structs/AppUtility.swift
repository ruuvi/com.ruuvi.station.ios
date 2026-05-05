import UIKit

enum AppUtility {
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }
        updateSupportedInterfaceOrientations()
    }

    private static func updateSupportedInterfaceOrientations() {
        let viewControllers = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .compactMap(\.rootViewController)

        if #available(iOS 16.0, *) {
            viewControllers.forEach {
                $0.setNeedsUpdateOfSupportedInterfaceOrientations()
                $0.presentedViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        } else {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}
