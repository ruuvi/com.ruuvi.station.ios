import UIKit

class MenuTableDismissTransitionAnimation: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning {
    var manager: MenuTableTransitionManager

    init(manager: MenuTableTransitionManager) {
        self.manager = manager
    }

    @objc func handleHideMenuPan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: pan.view!)
        let direction: CGFloat = manager.presentDirection == .left ? -1 : 1
        let distance = translation.x / MenuTableTransitionManager.appScreenRect.width * direction

        switch pan.state {
        case .began:
            if translation.x > 0 {
                return // don't start gesture
            }
            manager.isInteractive = true
            manager.menu.dismiss(animated: true)
        case .changed:
            update(max(min(distance, 1), 0))
        default:
            manager.isInteractive = false
            let velocity = pan.velocity(in: pan.view!).x * direction
            if velocity >= 100 || velocity >= -50 && distance >= 0.5 {
                finish()
            } else {
                cancel()
            }
        }
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.35
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let fromVC = transitionContext.viewController(forKey: .from)!
        let fromView = fromVC.view!

        let appearedFrame = transitionContext.finalFrame(for: fromVC)
        let initialFrame = appearedFrame
        let finalFrame = CGRect(x: -appearedFrame.size.width,
                                y: appearedFrame.origin.y,
                                width: appearedFrame.size.width,
                                height: appearedFrame.size.height)
        fromView.frame = initialFrame

        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration,
                       delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 1,
                       options: .curveEaseInOut,
                       animations: {
                           fromView.frame = finalFrame
                       }, completion: { _ in
                           if !transitionContext.transitionWasCancelled {
                               fromView.removeFromSuperview()
                           }
                           transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                       })
    }
}
