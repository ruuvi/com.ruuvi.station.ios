import UIKit

class MenuTablePresentTransitionAnimation: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning {
    
    var manager: MenuTableTransitionManager
    
    var presentDirection: UIRectEdge = .left
    
    private var switchMenus = false {
        didSet {
            if switchMenus {
                cancel()
            }
        }
    }
    
    init(manager: MenuTableTransitionManager) {
        self.manager = manager
    }
    
    @objc internal func handlePresentMenuLeftScreenEdge(_ edge: UIScreenEdgePanGestureRecognizer) {
        presentDirection = .left
        handlePresentMenuPan(edge)
    }
    
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
    
    func handlePresentMenuPan(_ pan: UIPanGestureRecognizer) {
//        if activeGesture == nil {
//            activeGesture = pan
//        } else if pan != activeGesture {
//            pan.isEnabled = false
//            pan.isEnabled = true
//            return
//        } else if pan.state != .began && pan.state != .changed {
//            activeGesture = nil
//        }
        
        guard let view = pan.view else {
            return
        }
        
        let transform = view.transform
        view.transform = .identity
        let translation = pan.translation(in: pan.view!)
        view.transform = transform
        
        // do some math to translate this to a percentage based value
        if !manager.isInteractive {
            if translation.x == 0 {
                return // not sure which way the user is swiping yet, so do nothing
            }
            
            if !(pan is UIScreenEdgePanGestureRecognizer) {
                presentDirection = translation.x > 0 ? .left : .right
            }
            
            manager.isInteractive = true
            manager.container.present(manager.menu, animated: true)
        }
        
        let direction: CGFloat = presentDirection == .left ? 1 : -1
        let distance = translation.x / manager.menuWidth
        // now lets deal with different states that the gesture recognizer sends
        switch (pan.state) {
        case .began, .changed:
            update(min(distance * direction, 1))
//            if pan is UIScreenEdgePanGestureRecognizer {
//                update(min(distance * direction, 1))
//            } else if distance > 0 && presentDirection == .right && sideMenuManager.menuLeftNavigationController != nil {
//                presentDirection = .left
//                switchMenus = true
//            } else if distance < 0 && presentDirection == .left && sideMenuManager.menuRightNavigationController != nil {
//                presentDirection = .right
//                switchMenus = true
//            } else {
//                update(min(distance * direction, 1))
//            }
        default:
            manager.isInteractive = false
            view.transform = .identity
            let velocity = pan.velocity(in: pan.view!).x * direction
            view.transform = transform
            if velocity >= 100 || velocity >= -50 && abs(distance) >= 0.5 {
                finish()
            } else {
                cancel()
            }
        }
    }
}
