import UIKit

class MenuTableTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    var manager: MenuTableTransitionManager
    
    lazy var present: MenuTablePresentTransitionAnimation = {
        return MenuTablePresentTransitionAnimation(manager: manager)
    }()
    lazy var dismiss: MenuTableDismissTransitionAnimation = {
        return MenuTableDismissTransitionAnimation(manager: manager)
    }()
    
    init(manager: MenuTableTransitionManager) {
        self.manager = manager
    }
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        let controller = MenuTablePresentationController(presentedViewController: presented, presenting: presenting)
        controller.menuWidth = manager.menuWidth
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
