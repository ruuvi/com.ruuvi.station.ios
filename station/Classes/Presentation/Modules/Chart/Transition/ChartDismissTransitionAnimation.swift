import UIKit

class ChartDismissTransitionAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let fromVC = transitionContext.viewController(forKey: .from)!
        let fromView = fromVC.view!
        
        let containerView = transitionContext.containerView
        
        let appearedFrame = transitionContext.finalFrame(for: fromVC)
        let initialFrame = appearedFrame
        let finalFrame = CGRect(x: appearedFrame.origin.x, y: containerView.bounds.size.height, width: appearedFrame.size.width, height: appearedFrame.size.height)
        fromView.frame = initialFrame
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.6, options: .curveEaseInOut, animations: {
            fromView.frame = finalFrame
        }) { finished in
            fromView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
