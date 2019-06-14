import UIKit

class RuuviTagAddPresentationController: UIPresentationController {
    
    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.7)
        view.alpha = 0
        view.addGestureRecognizer(tapGestureRecognizer)
        return view
    }()
    
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(RuuviTagAddPresentationController.dimmingViewTapped(_:)))
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
        let horizontalMargin = CGFloat(15)
        let width = parentSize.width - (2 * horizontalMargin)
        let height = 480.0 / 414.0 * width
        return CGSize(width: width, height: height)
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        get {
            var presentedViewFrame = CGRect.zero
            if let containerBounds = containerView?.bounds {
                let size = self.size(forChildContentContainer: presentedViewController, withParentContainerSize: containerBounds.size)
                presentedViewFrame.size = size
                presentedViewFrame.origin.x = (containerBounds.size.width / 2.0) - (size.width / 2.0)
                presentedViewFrame.origin.y = (containerBounds.height / 2.0) - (size.height / 2.0)
                
                if #available(iOS 11.0, *),
                    let bottomPadding = containerView?.safeAreaInsets.bottom {
                    presentedViewFrame.origin.y -= bottomPadding
                }
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
        if let ruuviTag = self.presentedViewController as? RuuviTagViewController {
            ruuviTag.output.viewDidTapOnDimmingView()
        }
    }
    
}
