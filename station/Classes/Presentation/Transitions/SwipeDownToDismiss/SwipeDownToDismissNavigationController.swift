import UIKit

class SwipeDownToDismissNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    lazy var panGR: UIPanGestureRecognizer = {
        let panGR = UIPanGestureRecognizer(target: self,
                                           action: #selector
                                           (SwipeDownToDismissNavigationController.handlePanGesture(_:)))
        panGR.delegate = self
        panGR.isEnabled = true
        return panGR
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addGestureRecognizer(panGR)
    }

    func gestureRecognizer(_: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool
    {
        true
    }

    @objc func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        if let transition = transitioningDelegate as? SwipeDownToDismissTransitioningDelegate {
            let interactor = transition.interactionControllerForDismissal
            let percentThreshold: CGFloat = 0.3

            // convert y-position to downward pull progress (percentage)
            let translation = sender.translation(in: view)
            let verticalMovement = translation.y / view.bounds.height
            let downwardMovement = fmaxf(Float(verticalMovement), 0.0)
            let downwardMovementPercent = fminf(downwardMovement, 1.0)
            let progress = CGFloat(downwardMovementPercent)

            switch sender.state {
            case .began:
                if let tagSettings = topViewController as? UITableViewController,
                   tagSettings.tableView.contentOffset.y <= 0
                {
                    interactor.hasStarted = true
                    dismiss(animated: true)
                }
            case .changed:
                interactor.shouldFinish = progress > percentThreshold
                interactor.update(progress)
            case .cancelled:
                interactor.hasStarted = false
                interactor.cancel()
            case .ended:
                interactor.hasStarted = false
                if interactor.shouldFinish {
                    interactor.finish()
                } else {
                    interactor.cancel()
                }
            default:
                break
            }
        }
    }
}
