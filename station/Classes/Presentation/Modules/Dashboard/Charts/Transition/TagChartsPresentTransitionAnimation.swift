import UIKit

class TagChartsPresentTransitionAnimation: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning {
    
    var manager: TagChartsTransitionManager
    
    init(manager: TagChartsTransitionManager) {
        self.manager = manager
    }
    
    @objc internal func handlePresentPan(_ pan: UIPanGestureRecognizer) {
        manager.presentDirection = .bottom
        handlePresent(pan)
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let toView = transitionContext.view(forKey: .to)!
        let toVC = transitionContext.viewController(forKey: .to)!
        
        let containerView = transitionContext.containerView
        containerView.addSubview(toView)
        
        toView.alpha = 0.0
        let finalFrame = transitionContext.finalFrame(for: toVC)
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration,
                       delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 1,
                       options: .curveEaseInOut,
                       animations: {
                        toView.alpha = 1.0
                        toView.frame = finalFrame
        }) { (finished) -> Void in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
    
    func handlePresent(_ pan: UIPanGestureRecognizer) {
        guard let view = pan.view else {
            return
        }
        
        let transform = view.transform
        view.transform = .identity
        let translation = pan.translation(in: pan.view!)
        view.transform = transform
        
        // do some math to translate this to a percentage based value
        if !manager.isInteractive {
            if translation.y >= 0 {
                return // not sure which way the user is swiping yet, so do nothing
            }
            
            if !(pan is UIScreenEdgePanGestureRecognizer) {
                manager.presentDirection = translation.y > 0 ? .bottom : .top
            }
            
            manager.isInteractive = true
            manager.container.present(manager.charts, animated: true)
        }
        
        let direction: CGFloat = manager.presentDirection == .top ? 1 : -1
        let distance = translation.y / TagChartsTransitionManager.appScreenRect.height
        // now lets deal with different states that the gesture recognizer sends
        switch (pan.state) {
        case .began, .changed:
            update(min(distance * direction, 1))
        default:
            manager.isInteractive = false
            view.transform = .identity
            let velocity = pan.velocity(in: pan.view!).y * direction
            view.transform = transform
            if velocity >= 100 || velocity >= -50 && abs(distance) >= 0.5 {
                finish()
            } else {
                cancel()
            }
        }
    }
}
