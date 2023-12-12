import UIKit

class MenuTablePresentationController: UIPresentationController {
    var menuWidth: CGFloat = 0
    var dismissTransition: MenuTableDismissTransitionAnimation!

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
        if #available(iOS 13, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        view.clipsToBounds = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowRadius = 5
        view.layer.shadowOpacity = 0.5
        view.layer.shadowOffset = CGSize(width: 0, height: 0)
        return view
    }()

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(MenuTablePresentationController.dimmingViewTapped(_:))
        )
        return tap
    }()

    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let exitPanGesture = UIPanGestureRecognizer()
        exitPanGesture.cancelsTouchesInView = false
        exitPanGesture.addTarget(
            dismissTransition as Any,
            action: #selector(MenuTableDismissTransitionAnimation.handleHideMenuPan(_:))
        )
        return exitPanGesture
    }()

    override var shouldPresentInFullscreen: Bool {
        true
    }

    override var adaptivePresentationStyle: UIModalPresentationStyle {
        .overFullScreen
    }

    override func size(
        forChildContentContainer _: UIContentContainer,
        withParentContainerSize parentSize: CGSize
    ) -> CGSize {
        CGSize(width: menuWidth, height: parentSize.height)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        var presentedViewFrame = CGRect.zero
        if let containerBounds = containerView?.bounds {
            let size = self.size(
                forChildContentContainer: presentedViewController,
                withParentContainerSize: containerBounds.size
            )
            presentedViewFrame.size = size
            presentedViewFrame.origin.x = containerBounds.origin.x
            presentedViewFrame.origin.y = containerBounds.origin.y
        }

        return presentedViewFrame
    }

    override func presentationTransitionWillBegin() {
        if let containerView {
            dimmingView.bounds = containerView.bounds
            dimmingView.alpha = 0

            shadowView.frame = .zero
        }

        containerView?.insertSubview(shadowView, at: 0)
        containerView?.insertSubview(dimmingView, at: 0)

        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { _ in
                self.shadowView.frame = self.presentedView?.frame ?? .zero
                self.dimmingView.alpha = 1.0
            }, completion: nil)
        } else {
            dimmingView.alpha = 1.0
        }
    }

    override func dismissalTransitionWillBegin() {
        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { _ in
                self.dimmingView.alpha = 0
                self.shadowView.frame = self.presentedView?.frame ?? .zero
            }, completion: nil)
        } else {
            dimmingView.alpha = 0
        }
    }

    override func containerViewWillLayoutSubviews() {
        if let bounds = containerView?.bounds {
            dimmingView.frame = bounds
        }
        presentedView?.frame = frameOfPresentedViewInContainerView
    }

    @objc func dimmingViewTapped(_: UITapGestureRecognizer) {
        if let navigationController = presentedViewController as? UINavigationController,
           let menuTable = navigationController.topViewController as? MenuTableViewController {
            menuTable.output.viewDidTapOnDimmingView()
        }
    }
}
