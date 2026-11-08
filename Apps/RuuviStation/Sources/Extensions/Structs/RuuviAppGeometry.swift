import RuuviLocalization
import UIKit

/// Replacements for the deprecated `UIScreen.main`.
///
/// On every device without a hinge (all iPhones and iPads) this *is* `UIScreen.main`, exactly as
/// before, also for an iPad window on an external display or a resized iPad window. Only on
/// iPhone Duo, where `UIScreen.main` is ambiguous, it is the screen of the display the app is
/// actually on (inner or outer).
enum RuuviAppGeometry {
    /// The screen `view` is shown on (iPhone Duo); `UIScreen.main` everywhere else.
    static func screen(for view: UIView?) -> UIScreen {
        guard RuuviDuoLayout.isFoldableDevice else {
            return UIScreen.main
        }
        if let screen = view?.window?.windowScene?.screen {
            return screen
        }
        if let screen = UIWindow.key?.windowScene?.screen {
            return screen
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first?.screen ?? UIScreen.main
    }

    /// Drop-in for `UIScreen.main.bounds`.
    static func bounds(for view: UIView?) -> CGRect {
        screen(for: view).bounds
    }

    /// Drop-in for `UIScreen.main.scale`.
    static func scale(for view: UIView?) -> CGFloat {
        screen(for: view).scale
    }

    /// Drop-in for `UIScreen.main.traitCollection`.
    static func screenTraits(for view: UIView?) -> UITraitCollection {
        screen(for: view).traitCollection
    }
}
