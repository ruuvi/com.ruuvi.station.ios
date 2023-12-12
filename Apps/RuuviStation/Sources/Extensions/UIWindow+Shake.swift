import UIKit
#if DEBUG && canImport(FLEX)
    import FLEX

    extension UIWindow {
        override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            super.motionEnded(motion, with: event)
            if motion == .motionShake {
                FLEXManager.shared.showExplorer()
            }
        }
    }
#endif
