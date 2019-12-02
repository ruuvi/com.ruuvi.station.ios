import UIKit

class TagChartsDismissTransitionAnimation: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning {

    var manager: TagChartsTransitionManager

    init(manager: TagChartsTransitionManager) {
        self.manager = manager
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35
    }

    @objc internal func handleHidePan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: pan.view!)
        let direction: CGFloat = manager.presentDirection == .top ? -1 : 1
        let distance = translation.y / TagChartsTransitionManager.appScreenRect.height * direction

        switch (pan.state) {
        case .began:
            if translation.y > 0 { return } // don't start gesture
            manager.isInteractive = true
            manager.charts.dismiss(animated: true)
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

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let fromView = transitionContext.view(forKey: .from)!
        let fromVC = transitionContext.viewController(forKey: .from)!
        fromView.alpha = 1.0
        let finalFrame = transitionContext.finalFrame(for: fromVC)

        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration,
                       delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 1,
                       options: .curveEaseInOut,
                       animations: {
                        fromView.alpha = 0.0
                        fromView.frame = finalFrame
        }) { (_) -> Void in
            if !transitionContext.transitionWasCancelled {
                fromView.removeFromSuperview()
            }
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
