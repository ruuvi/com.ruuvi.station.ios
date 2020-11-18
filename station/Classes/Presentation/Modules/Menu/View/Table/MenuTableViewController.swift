import UIKit

class MenuTableViewController: UIViewController {
    @IBOutlet weak var usernameLabel: UILabel!
    var output: MenuViewOutput!
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var refreshIcon: UIImageView!
    @IBOutlet weak var syncStatusLabel: UILabel!

    @IBAction func didPressSyncButton(_ sender: Any) {
        output.viewDidTapSyncButton()
    }

    var viewModel: MenuViewModel? {
        didSet {
            bindViewModel()
        }
    }
}

extension MenuTableViewController: MenuViewInput {
    func localize() {
        // do nothing
    }
}

extension MenuTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        output.viewDidLoad()
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
        usernameLabel.isHidden = !output.userIsAuthorized
        syncButton.isHidden = !output.userIsAuthorized
        refreshIcon.isHidden = !output.userIsAuthorized
        syncStatusLabel.isHidden = !output.userIsAuthorized
        configurePanToDismissGesture()
    }

    private func configurePanToDismissGesture() {
        if let transitioningDelegate = navigationController?.transitioningDelegate as? MenuTableTransitioningDelegate {
            let exitPanGesture = UIPanGestureRecognizer()
            exitPanGesture.cancelsTouchesInView = false
            exitPanGesture.addTarget(transitioningDelegate.dismiss,
                                     action: #selector(MenuTableDismissTransitionAnimation.handleHideMenuPan(_:)))
            view.addGestureRecognizer(exitPanGesture)
        }
    }

    private func startAnimating(duration: Double = 1) {
        let kAnimationKey = "rotation"
        if refreshIcon.layer.animation(forKey: kAnimationKey) == nil {
            let animate = CABasicAnimation(keyPath: "transform.rotation")
            animate.duration = duration
            animate.repeatCount = Float.infinity
            animate.fromValue = Float(.pi * 2.0)
            animate.toValue = 0.0
            refreshIcon.layer.add(animate, forKey: kAnimationKey)
        }
    }

    private func stopAnimating() {
        let kAnimationKey = "rotation"
        if refreshIcon.layer.animation(forKey: kAnimationKey) != nil {
            refreshIcon.layer.removeAnimation(forKey: kAnimationKey)
        }
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else {
            return
        }
        usernameLabel.bind(viewModel.username) { (label, username) in
            label.text = username
        }

        syncStatusLabel.bind(viewModel.status) { (label, syncStatus) in
            label.text = syncStatus
        }

        bind(viewModel.isSyncing) { (viewController, isSyncyng) in
            if isSyncyng == true {
                viewController.startAnimating()
                viewController.syncStatusLabel.text = "Syncing...".localized()
            } else {
                viewController.stopAnimating()
                viewController.syncStatusLabel.text = "".localized()
            }
        }
    }
}
