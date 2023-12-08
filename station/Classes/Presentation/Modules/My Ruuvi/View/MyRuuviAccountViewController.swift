import Foundation
import UIKit
import RuuviLocalization

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
        let message = RuuviLocalization.MyRuuvi.Settings.DeleteAccount.Confirmation.message
        let alertVC = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
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
            label.text = username == nil ? nil : RuuviLocalization.Menu.LoggedIn.title
        }
    }

    private func configureViews() {
        headerTitleLabel.text = RuuviLocalization.Menu.Label.MyRuuviAccount.text
        deleteAccountButton.setTitle(RuuviLocalization.MyRuuvi.Settings.DeleteAccount.title, for: .normal)
        deleteAccountButton.setTitle(RuuviLocalization.MyRuuvi.Settings.DeleteAccount.title, for: .normal)
        signoutButton.setTitle(RuuviLocalization.Menu.SignOut.text, for: .normal)
        signoutButton.setTitle(RuuviLocalization.Menu.SignOut.text, for: .highlighted)
    }
}
