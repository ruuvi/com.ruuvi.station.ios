import UIKit

class TagActionsPresentationController: UIPresentationController {
    
    var height: CGFloat = 0
    var dismissTransition: TagActionsDismissTransitionAnimation!
    
    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
        view.alpha = 0
        view.addGestureRecognizer(tapGestureRecognizer)
        view.addGestureRecognizer(panGestureRecognizer)
        return view
    }()
    
    private lazy var shadowView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.clipsToBounds = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowRadius = 5
        view.layer.shadowOpacity = 0.5
        view.layer.shadowOffset = CGSize(width: 0, height: 0)
        return view
    }()

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(TagActionsPresentationController.dimmingViewTapped(_:)))
        return tap
    }()
    
    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let exitPanGesture = UIPanGestureRecognizer()
        exitPanGesture.cancelsTouchesInView = false
        exitPanGesture.addTarget(dismissTransition as Any, action:#selector(TagActionsDismissTransitionAnimation.handleHidePan(_:)))
        return exitPanGesture
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
        return CGSize(width: parentSize.width, height: height)
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        get {
            var presentedViewFrame = CGRect.zero
            if let containerBounds = containerView?.bounds {
                let size = self.size(forChildContentContainer: presentedViewController, withParentContainerSize: containerBounds.size)
                presentedViewFrame.size = size
                presentedViewFrame.origin.x = containerBounds.origin.x
                presentedViewFrame.origin.y = containerBounds.origin.y + TagActionsTransitionManager.appScreenRect.height - height
            }
            
            return presentedViewFrame
        }
    }
    
    override func presentationTransitionWillBegin() {
        if let containerView = containerView {
            dimmingView.bounds = containerView.bounds
            dimmingView.alpha = 0
            
            shadowView.frame = frameOfPresentedViewInContainerView.insetBy(dx: 0, dy: height)
        }
        
        containerView?.insertSubview(shadowView, at: 0)
        containerView?.insertSubview(dimmingView, at: 0)
        
        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { (context) in
                self.shadowView.frame = self.presentedView?.frame ?? .zero
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
                self.shadowView.frame = self.presentedView?.frame ?? .zero
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
        if let tagActions = presentedViewController as? TagActionsViewController {
            tagActions.output.viewDidTapOnDimmingView()
        }
    }
    
}
