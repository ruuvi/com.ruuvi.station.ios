import UIKit

final class OwnerViewController: UIViewController {
    var output: OwnerViewOutput!

    @IBOutlet weak var claimOwnershipDescriptionLabel: UILabel!
    @IBOutlet weak var claimOwnershipButton: UIButton!

    @IBAction func claimOwnershipButtonTouchUpInside(_ sender: Any) {
        output.viewDidTapOnClaim()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
        claimOwnershipButton.setTitle("Owner.ClaimOwnership.button".localized(), for: .normal)
    }
    func showFirmwareUpdateDialog() {
        let message = "Cards.LegacyFirmwareUpdateDialog.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidIgnoreFirmwareUpdateDialog()
        }))
        let updatingInstructionTitle = "Cards.LegacyFirmwareUpdateDialog.ShowUpdatingInstructions.title".localized()
        alert.addAction(UIAlertAction(title: updatingInstructionTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog() {
        let message = "Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: nil))
        let updatingInstructionTitle = "Cards.LegacyFirmwareUpdateDialog.ShowUpdatingInstructions.title".localized()
        alert.addAction(UIAlertAction(title: updatingInstructionTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }
}
