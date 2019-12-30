import UIKit

class TagChartsTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    var manager: TagChartsTransitionManager
    
    lazy var present: TagChartsPresentTransitionAnimation = {
        return TagChartsPresentTransitionAnimation(manager: manager)
    }()
    lazy var dismiss: TagChartsDismissTransitionAnimation = {
        return TagChartsDismissTransitionAnimation(manager: manager)
    }()
    
    init(manager: TagChartsTransitionManager) {
        self.manager = manager
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return present
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismiss
    }
    
    func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return manager.isInteractive ? present : nil
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return manager.isInteractive ? dismiss : nil
    }
    
}
