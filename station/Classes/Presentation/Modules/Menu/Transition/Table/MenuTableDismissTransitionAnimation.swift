import UIKit

class MenuTableDismissTransitionAnimation: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning {
    
    var manager: MenuTableTransitionManager
    
    init(manager: MenuTableTransitionManager) {
        self.manager = manager
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let fromVC = transitionContext.viewController(forKey: .from)!
        let fromView = fromVC.view!
        
        let appearedFrame = transitionContext.finalFrame(for: fromVC)
        let initialFrame = appearedFrame
        let finalFrame = CGRect(x: -appearedFrame.size.width, y: appearedFrame.origin.y, width: appearedFrame.size.width, height: appearedFrame.size.height)
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
            
            fromView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
