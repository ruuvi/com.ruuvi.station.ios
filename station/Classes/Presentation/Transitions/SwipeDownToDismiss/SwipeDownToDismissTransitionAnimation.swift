import UIKit

class SwipeDownToDismissTransitionAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
        view.alpha = 0.9
        return view
    }()

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let fromVC = transitionContext.viewController(forKey: .from),
            let toVC = transitionContext.viewController(forKey: .to)
        else {
            return
        }
        let containerView = transitionContext.containerView

        // Fix layout bug in iOS 9+
        toVC.view.frame = transitionContext.finalFrame(for: toVC)

        containerView.insertSubview(toVC.view, belowSubview: fromVC.view)
        dimmingView.frame = containerView.bounds
        containerView.insertSubview(dimmingView, belowSubview: fromVC.view)

        let screenBounds = UIScreen.main.bounds
        let bottomLeftCorner = CGPoint(x: 0, y: screenBounds.height)
        let finalFrame = CGRect(origin: bottomLeftCorner, size: screenBounds.size)

        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            animations: {
                self.dimmingView.alpha = 0.0
                fromVC.view.frame = finalFrame
            }, completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        )
    }
}
