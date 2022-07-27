import UIKit

class MenuTableViewController: UIViewController {
    var output: MenuViewOutput!

    var isNetworkHidden: Bool = false {
        didSet {
            embeded?.isNetworkHidden = isNetworkHidden
            updateUIIsNetworkHidden()
        }
    }

    @IBOutlet weak var loggedInLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var networkContainer: UIView!

    var viewModel: MenuViewModel? {
        didSet {
            bindViewModel()
        }
    }

    private var embeded: MenuTableEmbededViewController?
}

extension MenuTableViewController: MenuViewInput {
    func localize() {
    }
}

extension MenuTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        configureViews()
        updateUI()
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

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else {
            return
        }
        usernameLabel.bind(viewModel.username) { label, username in
            label.text = username
        }
        loggedInLabel.bind(viewModel.username) { label, username in
            label.text = username == nil ? nil : "Menu.LoggedIn.title".localized()
        }
    }
}
