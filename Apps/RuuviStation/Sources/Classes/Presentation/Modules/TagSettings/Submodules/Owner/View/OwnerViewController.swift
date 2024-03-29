import RuuviLocalization
import UIKit

final class OwnerViewController: UIViewController {
    var output: OwnerViewOutput!

    var mode: OwnershipMode = .claim

    @IBOutlet var claimOwnershipDescriptionLabel: UILabel!
    @IBOutlet var removeCloudHistoryActionContainer: UIView!
    @IBOutlet var claimOwnershipButton: UIButton!

    private lazy var removeCloudHistoryCheckbox: RuuviCheckboxViewProvider = {
        let provider = RuuviCheckboxViewProvider(stateHolder: RuuviCheckboxViewState())
        return provider
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAsset.chevronBack.image
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    var removeCloudHistoryContainerVisibleConstraint: NSLayoutConstraint!
    var removeCloudHistoryContainerHiddenConstraint: NSLayoutConstraint!

    @IBAction func claimOwnershipButtonTouchUpInside(_: Any) {
        output.viewDidTapOnClaim(mode: mode)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpCustomBackButton()
        setUpCloudHistoryContentView()
        localize()
        styleViews()
        output.viewDidTriggerFirmwareUpdateDialog()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
        claimOwnershipDescriptionLabel.textColor = RuuviColor.textColor.color
        claimOwnershipButton.backgroundColor = RuuviColor.tintColor.color
    }
}

extension OwnerViewController: OwnerViewInput {
    func showSensorAlreadyClaimedDialog() {
        let alertVC = UIAlertController(
            title: RuuviLocalization.ErrorPresenterAlert.error,
            message: RuuviLocalization.UserApiError.erSensorAlreadyClaimedNoEmail,
            preferredStyle: .alert
        )
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .default, handler: {
            [weak self] _ in
            // TODO: - Update with masked email once backend is adjusted.
            self?.output.updateOwnerInfo(with: "*****")
        }))
        present(alertVC, animated: true)
    }

    func localize() {
        // No op.
        switch mode {
        case .claim:
            title = RuuviLocalization.Owner.title
            claimOwnershipDescriptionLabel.text = RuuviLocalization.Owner.Claim.description
            claimOwnershipButton.setTitle(RuuviLocalization.Owner.ClaimOwnership.button.capitalized, for: .normal)
        case .unclaim:
            title = RuuviLocalization.unclaimSensor
            claimOwnershipDescriptionLabel.text = RuuviLocalization.unclaimSensorDescription
            claimOwnershipButton.setTitle(RuuviLocalization.unclaim.capitalized, for: .normal)
        }
        removeCloudHistoryContainerVisibleConstraint.isActive = mode == .unclaim
        removeCloudHistoryContainerHiddenConstraint.isActive = mode == .claim

        removeCloudHistoryActionContainer.isHidden = mode == .claim
    }

    func showFirmwareUpdateDialog() {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidIgnoreFirmwareUpdateDialog()
        }))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog() {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: nil))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }

    func showUnclaimHistoryDataRemovalConfirmationDialog() {
        let title = RuuviLocalization.dialogAreYouSure
        let message = RuuviLocalization.dialogOperationUndone
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(
            UIAlertAction(
                title: RuuviLocalization.confirm,
                style: .destructive,
                handler: {
                    [weak self] _ in
                    guard let self else { return }
                    output?.viewDidConfirmUnclaim(
                        removeCloudHistory: removeCloudHistoryCheckbox.isChecked
                    )
                }
            )
        )
        controller.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

extension OwnerViewController {
    private func setUpCustomBackButton() {
        let backBarButtonItemView = UIView()
        backBarButtonItemView.addSubview(backButton)
        backButton.anchor(
            top: backBarButtonItemView.topAnchor,
            leading: backBarButtonItemView.leadingAnchor,
            bottom: backBarButtonItemView.bottomAnchor,
            trailing: backBarButtonItemView.trailingAnchor,
            padding: .init(top: 0, left: -16, bottom: 0, right: 0),
            size: .init(width: 48, height: 48)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)
    }

    private func setUpCloudHistoryContentView() {
        let removeCloudHistoryCheckboxVC = removeCloudHistoryCheckbox.makeViewController(
            title: RuuviLocalization.removeCloudHistoryDescription
        )
        removeCloudHistoryCheckboxVC.view.backgroundColor = .clear
        addChild(removeCloudHistoryCheckboxVC)
        view.addSubview(removeCloudHistoryCheckboxVC.view)
        removeCloudHistoryCheckboxVC.didMove(toParent: self)

        removeCloudHistoryActionContainer.addSubview(removeCloudHistoryCheckboxVC.view)
        removeCloudHistoryCheckboxVC.view.fillSuperview()

        view.addSubview(removeCloudHistoryActionContainer)
        removeCloudHistoryActionContainer.anchor(
            top: claimOwnershipDescriptionLabel.bottomAnchor,
            leading: claimOwnershipDescriptionLabel.leadingAnchor,
            bottom: nil,
            trailing: claimOwnershipDescriptionLabel.trailingAnchor,
            padding: .init(top: 24, left: 0, bottom: 0, right: 0)
        )
        removeCloudHistoryActionContainer.isHidden = true

        removeCloudHistoryContainerVisibleConstraint =
            claimOwnershipButton
                .topAnchor
                .constraint(
                    equalTo: removeCloudHistoryActionContainer.bottomAnchor,
                    constant: 40
                )
        removeCloudHistoryContainerHiddenConstraint =
            claimOwnershipButton
                .topAnchor
                .constraint(
                    equalTo: claimOwnershipDescriptionLabel.bottomAnchor,
                    constant: 40
                )
    }

    @objc private func backButtonDidTap() {
        output.viewDidDismiss()
    }
}
