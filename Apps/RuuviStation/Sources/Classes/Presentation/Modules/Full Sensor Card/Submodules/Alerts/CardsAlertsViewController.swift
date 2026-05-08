import UIKit
import SwiftUI
import Combine
import RuuviLocalization
import RuuviOntology

final class CardsAlertsViewController: UIViewController {
    weak var output: CardsAlertsViewOutput?

    private var cancellables = Set<AnyCancellable>()
    private let state: CardsSettingsState
    private let shouldExpandFirstAlertByDefault: Bool
    private var configuredSnapshotID: String
    private var actions = CardsSettingsActions()
    private var hasAppliedDefaultAlertExpansion = false
    private var customAlertDescriptionTextField = UITextField()
    private let customAlertDescriptionCharacterLimit = 32
    private var alertMinRangeTextField = UITextField()
    private var alertMaxRangeTextField = UITextField()
    private var cloudConnectionAlertDelayTextField = UITextField()
    private var cloudConnectionAlertDelayAction: UIAlertAction?
    private let cloudConnectionAlertDelayCharacterLimit: Int = 2
    private lazy var decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    init(
        snapshot: RuuviTagCardSnapshot,
        shouldExpandFirstAlertByDefault: Bool = false
    ) {
        self.state = CardsSettingsState(snapshot: snapshot)
        self.shouldExpandFirstAlertByDefault = shouldExpandFirstAlertByDefault
        self.configuredSnapshotID = snapshot.id
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        setupSubscriptions()
        output?.viewDidLoad()
    }
}

// MARK: - CardsAlertsViewInput
extension CardsAlertsViewController: CardsAlertsViewInput {
    func configure(snapshot: RuuviTagCardSnapshot) {
        resetDefaultAlertExpansionIfNeeded(for: snapshot)
        state.update(with: snapshot)
    }

    func updateAlertSections(_ sections: [CardsSettingsAlertSectionModel]) {
        state.setAlertSections(sections)
        expandFirstAlertSectionIfNeeded(with: sections)
    }
}

// MARK: - UITextFieldDelegate
extension CardsAlertsViewController: UITextFieldDelegate {

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let text = textField.text else {
            return true
        }
        let limit = text.utf16.count + string.utf16.count - range.length
        if textField == customAlertDescriptionTextField {
            return limit <= customAlertDescriptionCharacterLimit
        } else if textField == alertMinRangeTextField || textField == alertMaxRangeTextField {
            guard let decimalSeparator = NSLocale.current.decimalSeparator else {
                return true
            }

            var splitText = text.components(separatedBy: decimalSeparator)
            let totalDecimalSeparators = splitText.count - 1
            let isEditingEnd = (text.count - 3) < range.lowerBound

            splitText.removeFirst()

            if splitText.last?.count ?? 0 > 1, string.count != 0, isEditingEnd {
                return false
            }

            if totalDecimalSeparators > 0, string == decimalSeparator {
                return false
            }

            switch string {
            case "", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", decimalSeparator:
                return true
            default:
                return false
            }
        } else if textField == cloudConnectionAlertDelayTextField {
            let allowedCharacters = CharacterSet(charactersIn: "0123456789")
            let containsOnlyDigits = string.rangeOfCharacter(from: allowedCharacters.inverted) == nil
            return limit <= cloudConnectionAlertDelayCharacterLimit && containsOnlyDigits
        } else {
            return false
        }
    }
}

// MARK: - Private Helpers
private extension CardsAlertsViewController {
    func performWithoutAlertSectionAnimation(_ changes: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            changes()
        }
    }

    func resetDefaultAlertExpansionIfNeeded(for snapshot: RuuviTagCardSnapshot) {
        guard configuredSnapshotID != snapshot.id else { return }

        configuredSnapshotID = snapshot.id
        hasAppliedDefaultAlertExpansion = false
        performWithoutAlertSectionAnimation {
            state.expandedAlertSections.removeAll()
            state.clearLastExpandedAlertID()
        }
    }

    func expandFirstAlertSectionIfNeeded(
        with sections: [CardsSettingsAlertSectionModel]
    ) {
        guard shouldExpandFirstAlertByDefault,
              !hasAppliedDefaultAlertExpansion,
              state.expandedAlertSections.isEmpty,
              let firstSection = sections.first else {
            return
        }

        performWithoutAlertSectionAnimation {
            state.expandedAlertSections.insert(firstSection.id)
        }
        hasAppliedDefaultAlertExpansion = true
    }

    func setupSubscriptions() {
        actions.didToggleAlert
            .sink { [weak self] payload in
                self?.output?.viewDidChangeAlertState(for: payload.0, isOn: payload.1)
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

    func setUpUI() {
        view.backgroundColor = RuuviColor.primary.color

        let contentViewController = makeContentViewController()
        addChild(contentViewController)
        view.addSubview(contentViewController.view)
        contentViewController.view.fillSuperviewToSafeArea()
        contentViewController.didMove(toParent: self)
    }

    func makeContentViewController() -> UIViewController {
        let contentView = CardsAlertsView(state: state)
            .environmentObject(actions)
        let hostingController = UIHostingController(rootView: contentView)
        hostingController.view.backgroundColor = .clear
        return hostingController
    }

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
            output?.viewDidChangeAlertLowerBound(
                for: change.alertType,
                lower: CGFloat(change.lowerBound)
            )
        }

        if upperChanged {
            output?.viewDidChangeAlertUpperBound(
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
            self.output?.viewDidChangeAlertDescription(
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
            textField.placeholder = alertRangePlaceholder(
                isLower: true,
                slider: slider
            )
            textField.text = formattedValue(slider.selectedRange.lowerBound)
            alertMinRangeTextField = textField
            if slider.range.lowerBound < 0 {
                textField.addNumericAccessory()
            }
        }
        alert.addTextField { [weak self] textField in
            guard let self else { return }
            textField.delegate = self
            textField.keyboardType = .numbersAndPunctuation
            textField.placeholder = alertRangePlaceholder(
                isLower: false,
                slider: slider
            )
            textField.text = formattedValue(slider.selectedRange.upperBound)
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
                let lowerValue = parseValue(from: lowerField.text),
                let upperValue = parseValue(from: upperField.text),
                slider.range.contains(lowerValue),
                slider.range.contains(upperValue),
                lowerValue < upperValue
            else {
                return
            }
            self.output?.viewDidChangeAlertLowerBound(
                for: alertType,
                lower: CGFloat(lowerValue)
            )
            self.output?.viewDidChangeAlertUpperBound(
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
        let currentSeconds = RuuviAlertConstants.CloudConnection
            .normalizedUnseenDuration(config?.unseenDuration)
        let currentMinutes = Int(currentSeconds) / 60

        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self, weak alert] _ in
            guard let self, let minutesText = alert?.textFields?.first?.text else { return }
            defer { self.resetCloudConnectionDelayDialogState() }
            guard let minutes = Int(minutesText) else { return }
            let minimum = RuuviAlertConstants.CloudConnection.minUnseenDuration
            guard minutes >= minimum else { return }

            let seconds = minutes * 60
            if Int(currentSeconds) == seconds {
                return
            }
            self.output?.viewDidChangeCloudConnectionAlertUnseenDuration(duration: seconds)
        }
        action.isEnabled = isCloudConnectionDelayValid(minutesText: "\(currentMinutes)")
        cloudConnectionAlertDelayAction = action

        alert.addTextField { [weak self] textField in
            guard let self else { return }
            textField.keyboardType = .numberPad
            textField.text = "\(currentMinutes)"
            textField.delegate = self
            textField.addTarget(
                self,
                action: #selector(cloudConnectionDelayTextFieldDidChange(_:)),
                for: .editingChanged
            )
            cloudConnectionAlertDelayTextField = textField
        }

        alert.addAction(action)
        alert.addAction(
            UIAlertAction(title: RuuviLocalization.cancel, style: .cancel) { [weak self] _ in
                self?.resetCloudConnectionDelayDialogState()
            }
        )
        present(alert, animated: true)
    }

    @objc func cloudConnectionDelayTextFieldDidChange(_ textField: UITextField) {
        cloudConnectionAlertDelayAction?.isEnabled =
            isCloudConnectionDelayValid(minutesText: textField.text)
    }

    func isCloudConnectionDelayValid(minutesText: String?) -> Bool {
        guard let minutesText = minutesText,
              let minutes = Int(minutesText) else {
            return false
        }
        return minutes >= RuuviAlertConstants.CloudConnection.minUnseenDuration
    }

    func resetCloudConnectionDelayDialogState() {
        cloudConnectionAlertDelayTextField = UITextField()
        cloudConnectionAlertDelayAction = nil
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

private extension CardsAlertsViewController {
    func alertRangePlaceholder(
        isLower: Bool,
        slider: CardsSettingsAlertSliderConfiguration
    ) -> String {
        let value = isLower ? slider.range.lowerBound : slider.range.upperBound
        let hasFractional = value.truncatingRemainder(dividingBy: 1) != 0
        if slider.step < 1 || hasFractional {
            let label = isLower ? RuuviLocalization.chartStatMin : RuuviLocalization.chartStatMax
            return "\(label) (\(formattedValue(value)))"
        }
        if isLower {
            return RuuviLocalization.TagSettings.AlertSettings.Dialog.min(Float(value))
        }
        return RuuviLocalization.TagSettings.AlertSettings.Dialog.max(Float(value))
    }
}
