// swiftlint:disable file_length

import UIKit
import SwiftUI
import Combine
import RuuviLocalization
import RuuviOntology

final class CardsSettingsViewController: UIViewController {
    var output: CardsSettingsViewOutput!

    private var cancellables = Set<AnyCancellable>()
    private let state: CardsSettingsState
    private var actions = CardsSettingsActions()
    private var dashboardSortingType: DashboardSortingType?
    private var tagNameTextField = UITextField()
    private let tagNameCharaterLimit: Int = 32
    private var customAlertDescriptionTextField = UITextField()
    private let customAlertDescriptionCharacterLimit = 32
    private var alertMinRangeTextField = UITextField()
    private var alertMaxRangeTextField = UITextField()
    private var cloudConnectionAlertDelayTextField = UITextField()
    private let cloudConnectionAlertDelayCharaterLimit: Int = 2
    private lazy var decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
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

    init(
        snapshot: RuuviTagCardSnapshot
    ) {
        self.state = CardsSettingsState(snapshot: snapshot)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        setupSubscriptions()
        output.viewDidLoad()
    }
}

extension CardsSettingsViewController: CardsSettingsViewInput {

    func configure(
        snapshot: RuuviTagCardSnapshot, dashboardSortingType: DashboardSortingType?
    ) {
        state.update(with: snapshot)
        self.dashboardSortingType = dashboardSortingType
    }

    func updateAlertSections(_ sections: [CardsSettingsAlertSectionModel]) {
        state.setAlertSections(sections)
    }

    func showTagClaimDialog() {
        let title = RuuviLocalization.claimSensorOwnership
        let message = RuuviLocalization.doYouOwnSensor
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.yes,
            style: .default,
            handler: { [weak self] _ in
                self?.output.viewDidConfirmClaimTag()
            }
        ))
        controller.addAction(UIAlertAction(title: RuuviLocalization.no, style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showMacAddressDetail() {
        let title = RuuviLocalization.TagSettings.Mac.Alert.title
        let mac = state.snapshot.identifierData.mac?.value ??
            state.snapshot.identifierData.luid?.value ??
            RuuviLocalization.na
        let controller = UIAlertController(title: title, message: mac, preferredStyle: .alert)
        let copyAction = UIAlertAction(title: RuuviLocalization.copy, style: .default) { _ in
            UIPasteboard.general.string = mac
        }
        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil)
        controller.addAction(copyAction)
        controller.addAction(cancelAction)
        present(controller, animated: true)
    }

    func showFirmwareUpdateDialog() {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        let dismissAction = UIAlertAction(title: dismissTitle, style: .cancel) { [weak self] _ in
            self?.output.viewDidIgnoreFirmwareUpdateDialog()
        }
        let updateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        let updateAction = UIAlertAction(title: updateTitle, style: .default) { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }
        alert.addAction(dismissAction)
        alert.addAction(updateAction)
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog() {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        let dismissAction = UIAlertAction(title: dismissTitle, style: .cancel, handler: nil)
        let updateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        let updateAction = UIAlertAction(title: updateTitle, style: .default) { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }
        alert.addAction(dismissAction)
        alert.addAction(updateAction)
        present(alert, animated: true)
    }

    func showKeepConnectionTimeoutDialog() {
        resetKeepConnectionSwitch()
        let message = RuuviLocalization.TagSettings.PairError.Timeout.description
        let controller = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel))
        present(controller, animated: true)
    }

    func showKeepConnectionCloudModeDialog() {
        let message = RuuviLocalization.TagSettings.PairError.CloudMode.description
        let controller = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.ok,
            style: .cancel,
            handler: { [weak self] _ in
                self?.resetKeepConnectionSwitch()
            }
        ))
        present(controller, animated: true)
    }

    func stopKeepConnectionAnimatingDots() {
        state.setKeepConnectionDisplay(isInProgress: false)
    }

    func startKeepConnectionAnimatingDots() {
        state.setKeepConnectionDisplay(
            title: RuuviLocalization.TagSettings.PairAndBackgroundScan.Pairing.title,
            isOn: true,
            isInProgress: true
        )
    }

    func resetKeepConnectionSwitch() {
        state.setKeepConnectionDisplay(
            title: RuuviLocalization.TagSettings.PairAndBackgroundScan.Unpaired.title,
            isOn: false,
            isInProgress: false
        )
    }

    func freezeKeepConnectionDisplay() {
        state.freezeKeepConnectionDisplay()
    }

    func unfreezeKeepConnectionDisplay() {
        state.unfreezeKeepConnectionDisplay()
    }

    func updateVisibleMeasurementsSummary(
        value: String?,
        isVisible: Bool
    ) {
        state.updateVisibleMeasurementsSummary(
            value: value,
            isVisible: isVisible
        )
    }
}

// MARK: - UITextFieldDelegate

extension CardsSettingsViewController: UITextFieldDelegate {
    // swiftlint:disable:next cyclomatic_complexity
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,

        replacementString string: String
    ) -> Bool {
        guard let text = textField.text
        else {
            return true
        }
        let limit = text.utf16.count + string.utf16.count - range.length
        if textField == tagNameTextField {
            if limit <= tagNameCharaterLimit {
                return true
            } else {
                return false
            }
        } else if textField == customAlertDescriptionTextField {
            if limit <= customAlertDescriptionCharacterLimit {
                return true
            } else {
                return false
            }
        } else if textField == alertMinRangeTextField || textField == alertMaxRangeTextField {
            guard let text = textField.text, let decimalSeparator = NSLocale.current.decimalSeparator
            else {
                return true
            }

            var splitText = text.components(separatedBy: decimalSeparator)
            let totalDecimalSeparators = splitText.count - 1
            let isEditingEnd = (text.count - 3) < range.lowerBound

            splitText.removeFirst()

            // Check if we will exceed 2 dp
            if
                splitText.last?.count ?? 0 > 1, string.count != 0,
                isEditingEnd {
                return false
            }

            // If there is already a dot we don't want to allow further dots
            if totalDecimalSeparators > 0, string == decimalSeparator {
                return false
            }

            // Only allow numbers and decimal separator
            switch string {
            case "", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", decimalSeparator:
                return true
            default:
                return false
            }
        } else if textField == cloudConnectionAlertDelayTextField {
            if limit <= cloudConnectionAlertDelayCharaterLimit {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
}

extension CardsSettingsViewController {

    // swiftlint:disable:next function_body_length
    private func setupSubscriptions() {
        actions.didTapBackgroundChange
            .sink { [weak self] in
                self?.output.viewDidTriggerChangeBackground()
            }
            .store(in: &cancellables)

        actions.didTapSnapshotName
            .sink { [weak self] in
                self?.showSensorNameRenameDialog(
                    sortingType: self?.dashboardSortingType
                )
            }
            .store(in: &cancellables)

        actions.didTapOwnerRow
            .sink { [weak self] in
                self?.output.viewDidTapOnOwner()
            }
            .store(in: &cancellables)

        actions.didTapShareRow
            .sink { [weak self] in
                self?.output.viewDidTapShareButton()
            }
            .store(in: &cancellables)

        actions.didTapVisibleMeasurementsRow
            .sink { [weak self] in
                self?.output.viewDidTapVisibleMeasurements()
            }
            .store(in: &cancellables)

        actions.didTapMoreInfoMacAddress
            .sink { [weak self] in
                self?.output.viewDidTapOnMacAddress()
            }
            .store(in: &cancellables)

        actions.didTapMoreInfoTxPower
            .sink { [weak self] in
                self?.output.viewDidTapOnTxPower()
            }
            .store(in: &cancellables)

        actions.didTapMoreInfoMeasurementSequence
            .sink { [weak self] in
                self?.output.viewDidTapOnMeasurementSequenceNumber()
            }
            .store(in: &cancellables)

        actions.didTapTemperatureOffset
            .sink { [weak self] in
                self?.output.viewDidTapTemperatureOffsetCorrection()
            }
            .store(in: &cancellables)

        actions.didTapHumidityOffset
            .sink { [weak self] in
                self?.output.viewDidTapHumidityOffsetCorrection()
            }
            .store(in: &cancellables)

        actions.didTapPressureOffset
            .sink { [weak self] in
                self?.output.viewDidTapOnPressureOffsetCorrection()
            }
            .store(in: &cancellables)

        actions.didTapFirmwareUpdate
            .sink { [weak self] in
                self?.output.viewDidTapOnUpdateFirmware()
            }
            .store(in: &cancellables)

        actions.didTapRemove
            .sink { [weak self] in
                self?.output.viewDidAskToRemoveRuuviTag()
            }
            .store(in: &cancellables)

        actions.didToggleKeepConnection
            .sink { [weak self] isOn in
                self?.output.viewDidTriggerKeepConnection(isOn: isOn)
            }
            .store(in: &cancellables)

        actions.didTapNoValuesIndicator
            .sink { [weak self] in
                self?.output.viewDidTapOnNoValuesView()
            }
            .store(in: &cancellables)

        actions.didToggleAlert
            .sink { [weak self] payload in
                self?.output.viewDidChangeAlertState(for: payload.0, isOn: payload.1)
            }
            .store(in: &cancellables)

        actions.didChangeAlertRange
            .filter(\.isFinal)
            .sink { [weak self] change in
                self?.handleAlertRangeChange(change)
            }
            .store(in: &cancellables)

        actions.didRequestAlertDescriptionEdit
            .sink { [weak self] alertType in
                self?.presentAlertDescriptionDialog(for: alertType)
            }
            .store(in: &cancellables)

        actions.didRequestAlertLimitEdit
            .sink { [weak self] alertType in
                self?.presentAlertRangeDialog(for: alertType)
            }
            .store(in: &cancellables)

        actions.didTapCloudConnectionDelay
            .sink { [weak self] in
                self?.presentCloudConnectionDelayDialog()
            }
            .store(in: &cancellables)
    }
}

extension CardsSettingsViewController {
    private func setUpUI() {
        title = RuuviLocalization.TagSettings.NavigationItem.title
        view.backgroundColor = RuuviColor.primary.color

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

        let contentViewController = makeContentViewController()
        self.addChild(contentViewController)
        view.addSubview(contentViewController.view)
        contentViewController.view.fillSuperviewToSafeArea()
        contentViewController.didMove(toParent: self)
    }

    private func makeContentViewController() -> UIViewController {
        let contentView = CardsSettingsView(state: state)
            .environmentObject(actions)
        let hostingController = UIHostingController(rootView: contentView)
        hostingController.view.backgroundColor = .clear
        return hostingController
    }
}

private extension CardsSettingsViewController {
    @objc func backButtonDidTap() {
        output.viewDidAskToDismiss()
    }
}

private extension CardsSettingsViewController {
    func handleAlertRangeChange(_ change: CardsSettingsAlertRangeChange) {
        guard change.lowerBound < change.upperBound else { return }
        let current = sliderConfiguration(for: change.alertType)?.selectedRange
        let lowerChanged: Bool
        let upperChanged: Bool
        if let current {
            lowerChanged = abs(current.lowerBound - change.lowerBound) >= 0.0001
            upperChanged = abs(current.upperBound - change.upperBound) >= 0.0001
            if !lowerChanged, !upperChanged {
                return
            }
        } else {
            lowerChanged = true
            upperChanged = true
        }

        if lowerChanged {
            output.viewDidChangeAlertLowerBound(
                for: change.alertType,
                lower: CGFloat(change.lowerBound)
            )
        }

        if upperChanged {
            output.viewDidChangeAlertUpperBound(
                for: change.alertType,
                upper: CGFloat(change.upperBound)
            )
        }
    }

    func alertSection(
        for alertType: AlertType
    ) -> CardsSettingsAlertSectionModel? {
        state.alertSections.first { $0.alertType.rawValue == alertType.rawValue }
    }

    func sliderConfiguration(
        for alertType: AlertType
    ) -> CardsSettingsAlertSliderConfiguration? {
        alertSection(for: alertType)?.configuration.sliderConfiguration
    }

    func presentAlertDescriptionDialog(for alertType: AlertType) {
        guard let section = alertSection(for: alertType) else { return }
        let alert = UIAlertController(
            title: RuuviLocalization.TagSettings.Alert.CustomDescription.title,
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] textField in
            guard let self else { return }
            textField.delegate = self
            textField.text = section.configuration.customDescriptionText
            customAlertDescriptionTextField = textField
        }
        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self] _ in
            guard let self else { return }
            let text = customAlertDescriptionTextField.text?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value = (text?.isEmpty ?? true) ? nil : text
            self.output.viewDidChangeAlertDescription(
                for: alertType,
                description: value
            )
            self.customAlertDescriptionTextField = UITextField()
        }
        alert.addAction(action)
        alert.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel))
        present(alert, animated: true)
    }

    // swiftlint:disable:next function_body_length
    func presentAlertRangeDialog(for alertType: AlertType) {
        guard let section = alertSection(for: alertType),
              let slider = section.configuration.sliderConfiguration else {
            return
        }
        let alert = UIAlertController(
            title: section.title,
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] textField in
            guard let self else { return }
            textField.delegate = self
            textField.keyboardType = .numbersAndPunctuation
            textField.placeholder = RuuviLocalization.TagSettings.AlertSettings.Dialog.min(
                Float(slider.range.lowerBound)
            )
            textField.text = self.formattedValue(slider.selectedRange.lowerBound)
            alertMinRangeTextField = textField
            if slider.range.lowerBound < 0 {
                textField.addNumericAccessory()
            }
        }
        alert.addTextField { [weak self] textField in
            guard let self else { return }
            textField.delegate = self
            textField.keyboardType = .numbersAndPunctuation
            textField.placeholder = RuuviLocalization.TagSettings.AlertSettings.Dialog.max(
                Float(slider.range.upperBound)
            )
            textField.text = self.formattedValue(slider.selectedRange.upperBound)
            alertMaxRangeTextField = textField
            if slider.range.lowerBound < 0 {
                textField.addNumericAccessory()
            }
        }
        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self, weak alert] _ in
            guard
                let self,
                let lowerField = alert?.textFields?.first,
                let upperField = alert?.textFields?.last,
                let lowerValue = self.parseValue(from: lowerField.text),
                let upperValue = self.parseValue(from: upperField.text),
                slider.range.contains(lowerValue),
                slider.range.contains(upperValue),
                lowerValue < upperValue
            else {
                return
            }
            self.output.viewDidChangeAlertLowerBound(
                for: alertType,
                lower: CGFloat(lowerValue)
            )
            self.output.viewDidChangeAlertUpperBound(
                for: alertType,
                upper: CGFloat(upperValue)
            )
            self.alertMinRangeTextField = UITextField()
            self.alertMaxRangeTextField = UITextField()
        }
        alert.addAction(action)
        alert.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel))
        present(alert, animated: true)
    }

    func presentCloudConnectionDelayDialog() {
        let title = RuuviLocalization.alertCloudConnectionDialogTitle
        let message = RuuviLocalization.alertCloudConnectionDialogDescription
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let config = state.snapshot.getAlertConfig(
            for: .cloudConnection(unseenDuration: 0)
        )
        let currentSeconds = config?.unseenDuration ??
            Double(RuuviAlertConstants.CloudConnection.defaultUnseenDuration)
        let currentMinutes = max(1, Int(currentSeconds) / 60)

        alert.addTextField { [weak self] textField in
            guard let self else { return }
            textField.keyboardType = .numberPad
            textField.text = "\(currentMinutes)"
            textField.delegate = self
            cloudConnectionAlertDelayTextField = textField
        }

        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self, weak alert] _ in
            guard let self, let minutesText = alert?.textFields?.first?.text,
                  let minutes = Int(minutesText) else { return }
            let minimum = RuuviAlertConstants.CloudConnection.minUnseenDuration
            guard minutes >= minimum else { return }

            let seconds = minutes * 60
            if Int(currentSeconds) == seconds {
                return
            }
            self.output.viewDidChangeCloudConnectionAlertUnseenDuration(duration: seconds)
            self.cloudConnectionAlertDelayTextField = UITextField()
        }
        alert.addAction(action)
        alert.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel))
        present(alert, animated: true)
    }

    func parseValue(from text: String?) -> Double? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        if let number = decimalFormatter.number(from: trimmed) {
            return number.doubleValue
        }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    func formattedValue(_ value: Double) -> String {
        decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private extension CardsSettingsViewController {
     func showSensorNameRenameDialog(
        sortingType: DashboardSortingType?
    ) {
        let currenName = state.snapshot.displayData.name
        let defaultName = GlobalHelpers.ruuviDeviceDefaultName(
            from: state.snapshot.identifierData.mac?.mac,
            luid: state.snapshot.identifierData.luid?.value,
            dataFormat: state.snapshot.displayData.version
        )
        let alert = UIAlertController(
            title: RuuviLocalization.TagSettings.TagNameTitleLabel.text,
            message: sortingType == .alphabetical ?
                RuuviLocalization.TagSettings.TagNameTitleLabel.Rename.text : nil,
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] alertTextField in
            guard let self else { return }
            alertTextField.delegate = self
            alertTextField.text = (defaultName == currenName) ? nil : currenName
            alertTextField.placeholder = defaultName
            tagNameTextField = alertTextField
        }
        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self] _ in
            guard let self else { return }
            if let name = tagNameTextField.text, !name.isEmpty {
                output.viewDidChangeTag(name: name)
            } else {
                output.viewDidChangeTag(name: defaultName)
            }
        }
        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

// swiftlint:enable file_length
