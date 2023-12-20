import UIKit

class SwipeDownToDismissTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    let interactionControllerForDismissal = SwipeDownToDismissInteractiveTransition()

    func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        SwipeDownToDismissTransitionAnimation()
    }

    func interactionControllerForDismissal(using _: UIViewControllerAnimatedTransitioning)
    -> UIViewControllerInteractiveTransitioning? {
        interactionControllerForDismissal.hasStarted ? interactionControllerForDismissal : nil
    }
}
