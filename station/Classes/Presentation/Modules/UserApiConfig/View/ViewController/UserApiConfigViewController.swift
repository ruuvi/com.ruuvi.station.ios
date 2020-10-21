import UIKit

class UserApiConfigViewController: UIViewController {
    var output: UserApiConfigViewOutput!
    var viewModel: UserApiConfigViewModel! {
        didSet {
            bindViewModel()
        }
    }
    @IBOutlet weak var signOutBarButtonItem: UIBarButtonItem!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        output.viewDidLoad()
    }

    @IBAction func didSignOutButtonTap(_ sender: UIBarButtonItem) {
        output.viewDidSignOutButtonTap()
    }

    @IBAction func didCloseButtonTap(_ sender: UIBarButtonItem) {
        output.viewDidCloseButtonTap()
    }
}

// MARK: - UserApiConfigViewInput
extension UserApiConfigViewController: UserApiConfigViewInput {
    func localize() {
        signOutBarButtonItem.title = "UserApiConfig.SignOutButton".localized()
    }
}

// MARK: - Private
extension UserApiConfigViewController {
    private func bindViewModel() {
        bind(viewModel.title) { (viewController, title) in
            viewController.title = title
        }
    }
}
