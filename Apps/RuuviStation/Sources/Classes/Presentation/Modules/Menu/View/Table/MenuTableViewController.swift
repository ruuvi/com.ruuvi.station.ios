import RuuviLocalization
import UIKit

class MenuTableViewController: UIViewController {
    var output: MenuViewOutput!

    private var embeded: MenuTableEmbededViewController?
}

extension MenuTableViewController: MenuViewInput {
    func localize() {}
}

extension MenuTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        styleViews()
        configureViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
    }
}

extension MenuTableViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "EmbedMenuTableEmbededViewControllerSegueIdentifier" {
            embeded = segue.destination as? MenuTableEmbededViewController
            embeded?.output = output
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
            exitPanGesture.addTarget(
                transitioningDelegate.dismiss,
                action: #selector(MenuTableDismissTransitionAnimation.handleHideMenuPan(_:))
            )
            view.addGestureRecognizer(exitPanGesture)
        }
    }
}
