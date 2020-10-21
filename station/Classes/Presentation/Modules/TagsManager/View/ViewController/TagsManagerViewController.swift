import UIKit

class TagsManagerViewController: UIViewController {
    var output: TagsManagerViewOutput!
    var viewModel: TagsManagerViewModel! {
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

// MARK: - TagsManagerViewInput
extension TagsManagerViewController: TagsManagerViewInput {
    func localize() {
        signOutBarButtonItem.title = "TagsManager.SignOutButton".localized()
    }
}

// MARK: - Private
extension TagsManagerViewController {
    private func bindViewModel() {
        bind(viewModel.title) { (viewController, title) in
            viewController.title = title
        }
    }
}
