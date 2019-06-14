import UIKit

class MenuTablePresentationController: UIPresentationController {
    
    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.7)
        view.alpha = 0
        view.addGestureRecognizer(tapGestureRecognizer)
        return view
    }()
    
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(MenuTablePresentationController.dimmingViewTapped(_:)))
        return tap
    }()
    
    
    override var shouldPresentInFullscreen: Bool {
        get {
            return true
        }
    }
    
    override var adaptivePresentationStyle: UIModalPresentationStyle {
        get {
            return .overFullScreen
        }
    }
    
    override func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        return CGSize(width: parentSize.width / 1.5, height: parentSize.height)
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        get {
            var presentedViewFrame = CGRect.zero
            if let containerBounds = containerView?.bounds {
                let size = self.size(forChildContentContainer: presentedViewController, withParentContainerSize: containerBounds.size)
                presentedViewFrame.size = size
                presentedViewFrame.origin.x = containerBounds.origin.x
                presentedViewFrame.origin.y = containerBounds.origin.y
            }
            
            return presentedViewFrame
        }
    }
    
    override func presentationTransitionWillBegin() {
        if let containerView = containerView {
            dimmingView.bounds = containerView.bounds
            dimmingView.alpha = 0
        }
        
        containerView?.insertSubview(dimmingView, at: 0)
        
        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { (context) in
                self.dimmingView.alpha = 1.0
            }, completion: nil)
        } else {
            self.dimmingView.alpha = 1.0
        }
    }
    
    override func dismissalTransitionWillBegin() {
        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { (context) in
                self.dimmingView.alpha = 0
            }, completion: nil)
        } else {
            self.dimmingView.alpha = 0
        }
    }
    
    override func containerViewWillLayoutSubviews() {
        if let bounds = containerView?.bounds {
            dimmingView.frame = bounds
        }
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
    
    @objc func dimmingViewTapped(_ tap: UITapGestureRecognizer) {
        if let navigationController = self.presentedViewController as? UINavigationController, let menuTable = navigationController.topViewController as? MenuTableViewController {
            menuTable.output.viewDidTapOnDimmingView()
        }
    }
    
}
