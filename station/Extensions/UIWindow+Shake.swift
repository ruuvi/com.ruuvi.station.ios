import UIKit
#if canImport(FLEX)
import FLEX

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            FLEXManager.shared.showExplorer()
        }
    }
}
#endif
