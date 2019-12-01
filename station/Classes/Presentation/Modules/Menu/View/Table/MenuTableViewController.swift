import UIKit

class MenuTableViewController: UIViewController {
    var output: MenuViewOutput!
}

extension MenuTableViewController: MenuViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

extension MenuTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
    }
}

extension MenuTableViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "EmbedMenuTableEmbededViewControllerSegueIdentifier" {
            // swiftlint:disable force_cast
            let embeded = segue.destination as! MenuTableEmbededViewController
            // swiftlint:enable force_cast
            embeded.output = output
        }
    }
}

extension MenuTableViewController {
    private func configureViews() {
        configurePanToDismissGesture()
    }
    
    private func configurePanToDismissGesture() {
        if let transitioningDelegate = navigationController?.transitioningDelegate as? MenuTableTransitioningDelegate {
            let exitPanGesture = UIPanGestureRecognizer()
            exitPanGesture.cancelsTouchesInView = false
            exitPanGesture.addTarget(transitioningDelegate.dismiss, action:#selector(MenuTableDismissTransitionAnimation.handleHideMenuPan(_:)))
            view.addGestureRecognizer(exitPanGesture)
        }
    }
}
