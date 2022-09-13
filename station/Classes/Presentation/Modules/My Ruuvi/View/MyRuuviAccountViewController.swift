import Foundation
import UIKit

class MyRuuviAccountViewController: UIViewController {
    var output: MyRuuviAccountViewOutput!

    @IBOutlet weak var headerTitleLabel: UILabel!
    @IBOutlet weak var loggedInLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var signoutButton: UIButton!
    @IBOutlet weak var deleteAccountButton: UIButton!

    var viewModel: MyRuuviAccountViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        output.viewDidLoad()
    }

    // MARK: - Button actions
    @IBAction func backButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerClose()
    }

    @IBAction func deleteButtonTouchUpInside(_ sender: Any) {
        output.viewDidTapDeleteButton()
    }

    @IBAction func signoutButtonTouchUpInside(_ sender: Any) {
        output.viewDidTapSignoutButton()
    }
}

extension MyRuuviAccountViewController: MyRuuviAccountViewInput {
    func localize() {}

    func viewDidShowAccountDeletionConfirmation() {
        let message = "MyRuuvi.Settings.DeleteAccount.Confirmation.message".localized()
        let alertVC = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}

extension MyRuuviAccountViewController {
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

    private func configureViews() {
        headerTitleLabel.text = "Menu.Label.MyRuuviAccount.text".localized()
        deleteAccountButton.setTitle("MyRuuvi.Settings.DeleteAccount.title".localized(), for: .normal)
        deleteAccountButton.setTitle("MyRuuvi.Settings.DeleteAccount.title".localized(), for: .normal)
        signoutButton.setTitle("Menu.SignOut.text".localized(), for: .normal)
        signoutButton.setTitle("Menu.SignOut.text".localized(), for: .highlighted)
    }
}
