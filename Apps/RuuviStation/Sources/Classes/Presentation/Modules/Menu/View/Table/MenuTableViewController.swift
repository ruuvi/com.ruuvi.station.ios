import RuuviLocalization
import UIKit

class MenuTableViewController: UIViewController {
    var output: MenuViewOutput!

    private var embeded: MenuTableEmbededViewController?
    private var sideInsetSwitch: RuuviVerticalBarConstraintSwitch?
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
        configureSideInsetsForVerticalBar()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        sideInsetSwitch?.update(for: traitCollection)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
    }

    /// iPhone Duo: the storyboard pins the menu container to the view's edges. While the vertical
    /// bar is on a side of the display, pin it to the safe area instead so the menu doesn't run under
    /// the bar. The storyboard constraints stay active everywhere else (always on iPhone and iPad).
    private func configureSideInsetsForVerticalBar() {
        guard let container = embeded?.view.superview else { return }
        let storyboardConstraints = view.constraints.filter {
            ($0.firstItem as? UIView) === container &&
                ($0.secondItem as? UIView) === view &&
                ($0.firstAttribute == .leading || $0.firstAttribute == .trailing)
        }
        guard storyboardConstraints.count == 2 else { return }
        sideInsetSwitch = RuuviVerticalBarConstraintSwitch(
            standard: storyboardConstraints,
            verticalBar: [
                container.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            ]
        )
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
