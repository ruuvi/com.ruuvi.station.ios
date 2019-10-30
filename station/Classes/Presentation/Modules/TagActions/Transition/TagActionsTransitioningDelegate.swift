import UIKit

class TagActionsTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    var manager: TagActionsTransitionManager
    
    lazy var present: TagActionsPresentTransitionAnimation = {
        return TagActionsPresentTransitionAnimation(manager: manager)
    }()
    lazy var dismiss: TagActionsDismissTransitionAnimation = {
        return TagActionsDismissTransitionAnimation(manager: manager)
    }()
    
    init(manager: TagActionsTransitionManager) {
        self.manager = manager
    }
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        let controller = TagActionsPresentationController(presentedViewController: presented, presenting: presenting)
        controller.height = manager.height
        controller.dismissTransition = dismiss
        return controller
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return present
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismiss
    }
    
    func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return manager.isInteractive ? present : nil
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return manager.isInteractive ? dismiss : nil
    }
    
}
