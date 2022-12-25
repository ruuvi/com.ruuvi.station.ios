import UIKit

final class OwnerViewController: UIViewController {
    var output: OwnerViewOutput!

    @IBOutlet weak var claimOwnershipDescriptionLabel: UILabel!
    @IBOutlet weak var claimOwnershipButton: UIButton!

    private lazy var backButton: UIButton = {
        let button  = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAssets.backButtonImage
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    @IBAction func claimOwnershipButtonTouchUpInside(_ sender: Any) {
        output.viewDidTapOnClaim()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpCustomBackButton()
        setupLocalization()
        output.viewDidTriggerFirmwareUpdateDialog()
    }
}

extension OwnerViewController: OwnerViewInput {
    func showSensorAlreadyClaimedError(error: String, email: String?) {
        var message: String = ""
        if let email = email {
            // If there's email in the error
            message = String.localizedStringWithFormat(error.localized(),
                                                       email)
        } else {
            // if there's no email address in the error
            message = "UserApiError.ER_SENSOR_ALREADY_CLAIMED_NO_EMAIL".localized()
        }
        let alertVC = UIAlertController(title: "ErrorPresenterAlert.Error".localized(),
                                        message: message,
                                        preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .default, handler: { [weak self] _ in
            guard let email = email else {
                return
            }
            self?.output.update(with: email)
        }))
        present(alertVC, animated: true)
    }
    func localize() {
        title = "Owner.title".localized()
        claimOwnershipDescriptionLabel.text = "Owner.Claim.description".localized()
        claimOwnershipButton.setTitle("Owner.ClaimOwnership.button".localized().capitalized, for: .normal)
    }
    func showFirmwareUpdateDialog() {
        let message = "Cards.LegacyFirmwareUpdateDialog.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidIgnoreFirmwareUpdateDialog()
        }))
        let checkForUpdateTitle = "Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title".localized()
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog() {
        let message = "Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: nil))
        let checkForUpdateTitle = "Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title".localized()
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }
}

extension OwnerViewController {
    private func setUpCustomBackButton() {
        let backBarButtonItemView = UIView()
        backBarButtonItemView.addSubview(backButton)
        backButton.anchor(top: backBarButtonItemView.topAnchor,
                          leading: backBarButtonItemView.leadingAnchor,
                          bottom: backBarButtonItemView.bottomAnchor,
                          trailing: backBarButtonItemView.trailingAnchor,
                          padding: .init(top: 0, left: -8, bottom: 0, right: 0),
                          size: .init(width: 32, height: 32))
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)
    }

    @objc fileprivate func backButtonDidTap() {
        output.viewDidDismiss()
    }
}
