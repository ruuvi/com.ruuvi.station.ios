import UIKit

class TagActionsDismissTransitionAnimation: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning {
    
    var manager: TagActionsTransitionManager
    
    init(manager: TagActionsTransitionManager) {
        self.manager = manager
    }
    
    @objc internal func handleHidePan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: pan.view!)
        let direction: CGFloat = manager.presentDirection == .top ? -1 : 1
        let distance = translation.y / TagActionsTransitionManager.appScreenRect.height * direction
        
        switch (pan.state) {
        case .began:
            if translation.y > 0 { return } // don't start gesture
            manager.isInteractive = true
            manager.actions.dismiss(animated: true)
        case .changed:
            update(max(min(distance, 1), 0))
        default:
            manager.isInteractive = false
            let velocity = pan.velocity(in: pan.view!).y * direction
            if velocity >= 100 || velocity >= -50 && distance >= 0.5 {
                finish()
            } else {
                cancel()
            }
        }
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let fromVC = transitionContext.viewController(forKey: .from)!
        let fromView = fromVC.view!
        
        let appearedFrame = transitionContext.finalFrame(for: fromVC)
        let initialFrame = appearedFrame
        let finalFrame = CGRect(x: appearedFrame.origin.x, y: appearedFrame.origin.y + manager.height, width: appearedFrame.size.width, height: appearedFrame.size.height)
        fromView.frame = initialFrame
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration,
                       delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 1,
                       options: .curveEaseInOut,
                       animations: {
                        fromView.frame = finalFrame
        }) { (finished) -> Void in
            if !transitionContext.transitionWasCancelled {
                fromView.removeFromSuperview()
            }
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
