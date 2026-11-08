import RuuviLocalization
import UIKit

enum AppUtility {
    /// iPhone Duo: `true` while the device is open (partially or fully), i.e. the app is on the inner
    /// display. Always `false` on devices without a hinge (every iPhone and iPad).
    private static var isFoldableDeviceOpen = false

    /// `true` once the device reported a hinge (iPhone Duo). Always `false` on iPhone and iPad.
    static var isFoldableDevice: Bool { RuuviDuoLayout.isFoldableDevice }

    /// The orientations to report from `application(_:supportedInterfaceOrientationsFor:)`.
    ///
    /// On iPhone Duo's inner display a portrait lock (onboarding, sign in) would show the app as a
    /// portrait box in the middle of the display, so the lock is lifted while the device is open.
    /// The outer display keeps the lock. On iPhone and iPad this is always `lock`.
    static func supportedOrientations(lock: UIInterfaceOrientationMask) -> UIInterfaceOrientationMask {
        isFoldableDeviceOpen ? .all : lock
    }

    /// Called with hinge updates (see `SceneDelegate`). Never changes anything on iPhone and iPad,
    /// which report no hinge.
    static func updateFoldableDevice(hasHinge: Bool, isOpen: Bool) {
        if hasHinge {
            RuuviDuoLayout.noteHingePresent()
        }
        guard isOpen != isFoldableDeviceOpen else { return }
        isFoldableDeviceOpen = isOpen
        updateSupportedInterfaceOrientations()
    }

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
