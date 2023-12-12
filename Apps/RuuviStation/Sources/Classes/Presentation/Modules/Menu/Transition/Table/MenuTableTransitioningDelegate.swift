import UIKit

class MenuTableTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    var manager: MenuTableTransitionManager

    lazy var present: MenuTablePresentTransitionAnimation = .init(manager: manager)

    lazy var dismiss: MenuTableDismissTransitionAnimation = .init(manager: manager)

    init(manager: MenuTableTransitionManager) {
        self.manager = manager
    }

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source _: UIViewController
    ) -> UIPresentationController? {
        let controller = MenuTablePresentationController(presentedViewController: presented, presenting: presenting)
        controller.menuWidth = manager.menuWidth
        controller.dismissTransition = dismiss
        return controller
    }

    func animationController(
        forPresented _: UIViewController,
        presenting _: UIViewController,
        source _: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        present
    }

    func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        dismiss
    }

    func interactionControllerForPresentation(using _: UIViewControllerAnimatedTransitioning)
    -> UIViewControllerInteractiveTransitioning? {
        manager.isInteractive ? present : nil
    }

    func interactionControllerForDismissal(using _: UIViewControllerAnimatedTransitioning)
    -> UIViewControllerInteractiveTransitioning? {
        manager.isInteractive ? dismiss : nil
    }
}
