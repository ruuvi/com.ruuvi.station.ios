import UIKit

class TagSettingsTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    let interactionControllerForDismissal = TagSettingsDismissInteractiveTransition()
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return TagSettingsDismissTransitionAnimation()
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionControllerForDismissal.hasStarted ? interactionControllerForDismissal : nil
    }
}
