import UIKit

class SwipeDownToDismissTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {

    let interactionControllerForDismissal = SwipeDownToDismissInteractiveTransition()

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SwipeDownToDismissTransitionAnimation()
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionControllerForDismissal.hasStarted ? interactionControllerForDismissal : nil
    }
}
