import UIKit

class MenuTablePresentTransitionAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let toVC = transitionContext.viewController(forKey: .to)!
        let toView = transitionContext.view(forKey: .to)!
        
        let containerView = transitionContext.containerView
        containerView.addSubview(toView)
        
        let appearedFrame = transitionContext.finalFrame(for: toVC)
        let initialFrame = CGRect(x: -appearedFrame.size.width, y: appearedFrame.origin.y, width: appearedFrame.size.width, height: appearedFrame.size.height)
        let finalFrame = appearedFrame
        toView.frame = initialFrame
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration,
                       delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 1,
                       options: .curveEaseInOut,
                       animations: {
                        toView.frame = finalFrame
        }) { (finished) -> Void in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
