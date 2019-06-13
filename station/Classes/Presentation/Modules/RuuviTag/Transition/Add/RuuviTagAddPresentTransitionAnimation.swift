import UIKit

class RuuviTagAddPresentTransitionAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let toVC = transitionContext.viewController(forKey: .to)!
        let toView = transitionContext.view(forKey: .to)!
        
        let containerView = transitionContext.containerView
        containerView.addSubview(toView)
        
        let appearedFrame = transitionContext.finalFrame(for: toVC)
        let initialFrame = CGRect(x: appearedFrame.origin.x, y: containerView.bounds.size.height, width: appearedFrame.size.width, height: appearedFrame.size.height)
        let finalFrame = appearedFrame
        toView.frame = initialFrame
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
            toView.frame = finalFrame
        }) { finished in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
