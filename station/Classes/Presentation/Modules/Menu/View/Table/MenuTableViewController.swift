import UIKit

class MenuTableViewController: UIViewController {
    var output: MenuViewOutput!

    var isNetworkHidden: Bool = false {
        didSet {
            embeded?.isNetworkHidden = isNetworkHidden
            updateUIIsNetworkHidden()
        }
    }

    @IBOutlet weak var ruuviNetworkStatusLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var refreshIcon: UIImageView!
    @IBOutlet weak var syncStatusLabel: UILabel!
    @IBOutlet weak var syncContainer: UIView!
    @IBOutlet weak var networkContainer: UIView!

    @IBAction func didPressSyncButton(_ sender: Any) {
        output.viewDidTapSyncButton()
    }

    var viewModel: MenuViewModel? {
        didSet {
            bindViewModel()
        }
    }

    private var embeded: MenuTableEmbededViewController?
}

extension MenuTableViewController: MenuViewInput {
    func localize() {
        ruuviNetworkStatusLabel.text = "Menu.RuuviNetworkStatus.text".localized()
    }
}

extension MenuTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        configureViews()
        updateUI()
        output.viewDidLoad()
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
    private func updateUI() {
        updateUIIsNetworkHidden()
    }

    private func updateUIIsNetworkHidden() {
        if isViewLoaded {
            networkContainer.isHidden = isNetworkHidden
        }
    }
}

extension MenuTableViewController {
    private func configureViews() {
        syncContainer.isHidden = !output.userIsAuthorized
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
            label.text = String(format: "MenuTableViewController.User".localized(),
                                username ?? "MenuTableViewController.None".localized())
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
            }
        }
    }
}
