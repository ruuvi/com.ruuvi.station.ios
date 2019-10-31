import UIKit

class TagActionsPresentationController: UIPresentationController {
    
    var height: CGFloat = 0
    var dismissTransition: TagActionsDismissTransitionAnimation!
    
    private var leftDoorPortrait: CATransform3D {
        let w = TagActionsTransitionManager.appScreenRect.width
        let h = TagActionsTransitionManager.appScreenRect.height
        var t = CATransform3DIdentity
        t.m34 = 1.0 / 800
        t = CATransform3DRotate(t, CGFloat(Double.pi) * -45.0/180.0, 0, 1, 0)
        let scale: CGFloat = 0.7
        let rw = w / sqrt(2)
        let x = scale * (w - rw) / 2
        t = CATransform3DTranslate(t, -x, -h*0.15, 100)
        t = CATransform3DScale(t, scale, scale, 1.0)
        return t
    }
    
    private var rightDoorPortrait: CATransform3D {
        let w = TagActionsTransitionManager.appScreenRect.width
        let h = TagActionsTransitionManager.appScreenRect.height
        var t = CATransform3DIdentity
        t.m34 = 1.0 / 800
        t = CATransform3DRotate(t, CGFloat(Double.pi) * 45.0/180.0, 0, 1, 0)
        let scale: CGFloat = 0.7
        let rw = w / sqrt(2)
        let x = scale * (w - rw) / 2
        t = CATransform3DTranslate(t, x, -h*0.15, 100)
        t = CATransform3DScale(t, scale, scale, 1.0)
        return t
    }
    
    private var leftDoorLandscape: CATransform3D {
        let w = TagActionsTransitionManager.appScreenRect.width
        let h = TagActionsTransitionManager.appScreenRect.height
        var t = CATransform3DIdentity
        t.m34 = 1.0 / 800
        t = CATransform3DRotate(t, CGFloat(Double.pi) * -45.0/180.0, 0, 1, 0)
        let scale: CGFloat = 0.52
        let rw = w / sqrt(2)
        let x = scale * (w - rw) / 2
        t = CATransform3DTranslate(t, -x * 2.0, -h*0.15, 100)
        t = CATransform3DScale(t, scale, scale, 1.0)
        return t
    }
    
    private var rightDoorLandscape: CATransform3D {
        let w = TagActionsTransitionManager.appScreenRect.width
        let h = TagActionsTransitionManager.appScreenRect.height
        var t = CATransform3DIdentity
        t.m34 = 1.0 / 800
        t = CATransform3DRotate(t, CGFloat(Double.pi) * 45.0/180.0, 0, 1, 0)
        let scale: CGFloat = 0.52
        let rw = w / sqrt(2)
        let x = scale * (w - rw) / 2
        t = CATransform3DTranslate(t, x * 2.0, -h*0.15, 100)
        t = CATransform3DScale(t, scale, scale, 1.0)
        return t
    }
    
    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
        view.alpha = 0
        view.addGestureRecognizer(tapGestureRecognizer)
        view.addGestureRecognizer(panGestureRecognizer)
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let identity = CATransform3DIdentity
        presentingViewController.view.layer.transform = identity
        presentingViewController.presentingViewController?.view.layer.transform = identity
        coordinator.animate(alongsideTransition: { (context) in
            if UIApplication.shared.statusBarOrientation.isLandscape {
                self.presentingViewController.view.layer.transform = self.rightDoorLandscape
                self.presentingViewController.presentingViewController?.view.layer.transform = self.leftDoorLandscape
            } else {
                self.presentingViewController.view.layer.transform = self.rightDoorPortrait
                self.presentingViewController.presentingViewController?.view.layer.transform = self.leftDoorPortrait
            }
        }) { (context) in
            
        }
        super.viewWillTransition(to: size, with: coordinator)
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
        }
        
        containerView?.insertSubview(dimmingView, at: 0)
        
        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { (context) in
                self.dimmingView.alpha = 1.0
                if UIApplication.shared.statusBarOrientation.isLandscape {
                    self.presentingViewController.view.layer.transform = self.rightDoorLandscape
                    self.presentingViewController.presentingViewController?.view.layer.transform = self.leftDoorLandscape
                } else {
                    self.presentingViewController.view.layer.transform = self.rightDoorPortrait
                    self.presentingViewController.presentingViewController?.view.layer.transform = self.leftDoorPortrait
                }
            }, completion: nil)
        } else {
            self.dimmingView.alpha = 1.0
        }
    }

    override func dismissalTransitionWillBegin() {
        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            let identity = CATransform3DIdentity
            transitionCoordinator.animate(alongsideTransition: { (context) in
                self.dimmingView.alpha = 0
                
                self.presentingViewController.view.layer.transform = identity
                self.presentingViewController.presentingViewController?.view.layer.transform = identity
                
            }, completion: { context in
                self.presentingViewController.view.setNeedsLayout()
                self.presentingViewController.view.layoutIfNeeded()
                self.presentingViewController.presentingViewController?.view.setNeedsLayout()
                self.presentingViewController.presentingViewController?.view.layoutIfNeeded()
            })
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
