// swiftlint:disable file_length
import UIKit
import RangeSeekSlider
import RuuviOntology

enum TagSettingsTableSection: Int {
    case image = 0
    case name = 1
    case connection = 2
    case alerts = 3
    case offsetCorrection = 4
    case moreInfo = 5
    case firmware = 6
    case networkInfo = 7

    static func showConnection(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.isConnectable.value ?? false
    }

    static func showAlerts(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.isAlertsEnabled.value ?? false
    }

    static func section(for sectionIndex: Int) -> TagSettingsTableSection {
        return TagSettingsTableSection(rawValue: sectionIndex) ?? .name
    }

    static func showNetworkInfo(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.isAuthorized.value == true
            && viewModel?.owner.value?.isEmpty == false
    }

    static func showUpdateFirmware(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.canShowUpdateFirmware.value ?? false
    }
}

class TagSettingsTableViewController: UITableViewController {
    var output: TagSettingsViewOutput!

    @IBOutlet weak var movementAlertDescriptionCell: TagSettingsAlertDescriptionCell!
    @IBOutlet weak var movementAlertHeaderCell: TagSettingsAlertHeaderCell!

    @IBOutlet weak var connectionAlertDescriptionCell: TagSettingsAlertDescriptionCell!
    @IBOutlet weak var connectionAlertHeaderCell: TagSettingsAlertHeaderCell!

    @IBOutlet weak var pressureAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var pressureAlertControlsCell: TagSettingsAlertControlsCell!

    @IBOutlet weak var dewPointAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var dewPointAlertControlsCell: TagSettingsAlertControlsCell!

    @IBOutlet weak var temperatureAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var temperatureAlertControlsCell: TagSettingsAlertControlsCell!

    @IBOutlet weak var humidityAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var humidityAlertControlsCell: TagSettingsAlertControlsCell!

    @IBOutlet weak var rhAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var rhAlertControlsCell: TagSettingsAlertControlsCell!

    @IBOutlet weak var networkOwnerCell: UITableViewCell!
    @IBOutlet weak var networkOwnerLabel: UILabel!
    @IBOutlet weak var networkOwnerValueLabel: UILabel!

    @IBOutlet weak var networkTagActionsStackView: UIStackView!
    @IBOutlet weak var claimTagButton: UIButton!
    @IBOutlet weak var shareTagButton: UIButton!

    @IBOutlet weak var connectStatusLabel: UILabel!
    @IBOutlet weak var keepConnectionSwitch: UISwitch!
    @IBOutlet weak var keepConnectionTitleLabel: UILabel!
    @IBOutlet weak var dataSourceTitleLabel: UILabel!
    @IBOutlet weak var dataSourceValueLabel: UILabel!

    @IBOutlet weak var macValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var txPowerValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var msnValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var msnCell: UITableViewCell!
    @IBOutlet weak var txPowerCell: UITableViewCell!
    @IBOutlet weak var uuidCell: UITableViewCell!
    @IBOutlet weak var macAddressCell: UITableViewCell!
    @IBOutlet weak var tagNameCell: UITableViewCell!
    @IBOutlet weak var uuidValueLabel: UILabel!
    @IBOutlet weak var accelerationXValueLabel: UILabel!
    @IBOutlet weak var accelerationYValueLabel: UILabel!
    @IBOutlet weak var accelerationZValueLabel: UILabel!
    @IBOutlet weak var voltageValueLabel: UILabel!
    @IBOutlet weak var macAddressValueLabel: UILabel!
    @IBOutlet weak var rssiValueLabel: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var uploadBackgroundIndicatorView: UIView!
    @IBOutlet weak var uploadBackgroundProgressLabel: UILabel!
    @IBOutlet weak var tagNameTextField: UITextField!
    @IBOutlet weak var dataFormatValueLabel: UILabel!
    @IBOutlet weak var msnValueLabel: UILabel!
    @IBOutlet weak var txPowerValueLabel: UILabel!
    @IBOutlet weak var backgroundImageLabel: UILabel!
    @IBOutlet weak var tagNameTitleLabel: UILabel!
    @IBOutlet weak var uuidTitleLabel: UILabel!
    @IBOutlet weak var macAddressTitleLabel: UILabel!
    @IBOutlet weak var rssiTitleLabel: UILabel!
    @IBOutlet weak var dataFormatTitleLabel: UILabel!
    @IBOutlet weak var batteryVoltageTitleLabel: UILabel!
    @IBOutlet weak var accelerationXTitleLabel: UILabel!
    @IBOutlet weak var accelerationYTitleLabel: UILabel!
    @IBOutlet weak var accelerationZTitleLabel: UILabel!
    @IBOutlet weak var txPowerTitleLabel: UILabel!
    @IBOutlet weak var msnTitleLabel: UILabel!

    @IBOutlet weak var temperatureOffsetCorrectionCell: UITableViewCell!
    @IBOutlet weak var humidityOffsetCorrectionCell: UITableViewCell!
    @IBOutlet weak var pressureOffsetCorrectionCell: UITableViewCell!
    @IBOutlet weak var temperatureOffsetTitleLabel: UILabel!
    @IBOutlet weak var temperatureOffsetValueLabel: UILabel!
    @IBOutlet weak var humidityOffsetTitleLabel: UILabel!
    @IBOutlet weak var humidityOffsetValueLabel: UILabel!
    @IBOutlet weak var pressureOffsetTitleLabel: UILabel!
    @IBOutlet weak var pressureOffsetValueLabel: UILabel!
    @IBOutlet weak var updateFirmwareCell: UITableViewCell!
    @IBOutlet weak var updateFirmwareTitleLabel: UILabel!

    @IBOutlet weak var removeThisRuuviTagButton: UIButton!
    @IBOutlet weak var footerView: UIView!

    var viewModel: TagSettingsViewModel? {
        didSet {
            bindViewModel()
        }
    }

    var measurementService: MeasurementsService!

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.default
    }

    private let moreInfoSectionHeaderReuseIdentifier = "TagSettingsMoreInfoHeaderFooterView"
    private let alertsSectionHeaderReuseIdentifier = "TagSettingsAlertsHeaderFooterView"
    private let alertOffString = "TagSettings.Alerts.Off"
    private static var localizedCache: LocalizedCache = LocalizedCache()
}

// MARK: - TagSettingsViewInput
extension TagSettingsTableViewController: TagSettingsViewInput {

    // swiftlint:disable:next function_body_length
    func localize() {
        navigationItem.title = "TagSettings.navigationItem.title".localized()
        backgroundImageLabel.text = "TagSettings.backgroundImageLabel.text".localized()
        tagNameTitleLabel.text = "TagSettings.tagNameTitleLabel.text".localized()
        rssiTitleLabel.text = "TagSettings.rssiTitleLabel.text".localized()
        uuidTitleLabel.text = "TagSettings.uuidTitleLabel.text".localized()
        macAddressTitleLabel.text = "TagSettings.macAddressTitleLabel.text".localized()
        dataFormatTitleLabel.text = "TagSettings.dataFormatTitleLabel.text".localized()
        batteryVoltageTitleLabel.text = "TagSettings.batteryVoltageTitleLabel.text".localized()
        accelerationXTitleLabel.text = "TagSettings.accelerationXTitleLabel.text".localized()
        accelerationYTitleLabel.text = "TagSettings.accelerationYTitleLabel.text".localized()
        accelerationZTitleLabel.text = "TagSettings.accelerationZTitleLabel.text".localized()
        txPowerTitleLabel.text = "TagSettings.txPowerTitleLabel.text".localized()
        msnTitleLabel.text = "TagSettings.msnTitleLabel.text".localized()
        dataSourceTitleLabel.text = "TagSettings.dataSourceTitleLabel.text".localized()
        removeThisRuuviTagButton.setTitle("TagSettings.removeThisRuuviTagButton.text".localized(), for: .normal)

        updateUITemperatureAlertDescription()
        keepConnectionTitleLabel.text = "TagSettings.KeepConnection.title".localized()
        humidityAlertHeaderCell.titleLabel.text
            = "TagSettings.AirHumidityAlert.title".localized()
        rhAlertHeaderCell.titleLabel.text
            = "TagSettings.AirHumidityAlert.title".localized()
        pressureAlertHeaderCell.titleLabel.text
            = "TagSettings.PressureAlert.title".localized()
        connectionAlertHeaderCell.titleLabel.text = "TagSettings.ConnectionAlert.title".localized()
        movementAlertHeaderCell.titleLabel.text = "TagSettings.MovementAlert.title".localized()

        let alertPlaceholder = "TagSettings.Alert.CustomDescription.placeholder".localized()
        temperatureAlertControlsCell.textField.placeholder = alertPlaceholder
        humidityAlertControlsCell.textField.placeholder = alertPlaceholder
        rhAlertControlsCell.textField.placeholder = alertPlaceholder
        dewPointAlertControlsCell.textField.placeholder = alertPlaceholder
        pressureAlertControlsCell.textField.placeholder = alertPlaceholder
        connectionAlertDescriptionCell.textField.placeholder = alertPlaceholder
        movementAlertDescriptionCell.textField.placeholder = alertPlaceholder

        temperatureOffsetTitleLabel.text = "TagSettings.OffsetCorrection.Temperature".localized()
        humidityOffsetTitleLabel.text = "TagSettings.OffsetCorrection.Humidity".localized()
        pressureOffsetTitleLabel.text = "TagSettings.OffsetCorrection.Pressure".localized()

        updateFirmwareTitleLabel.text = "TagSettings.Firmware.UpdateFirmware".localized()

        claimTagButton.setTitle("TagSettings.ClaimTagButton.Claim".localized(), for: .normal)
        shareTagButton.setTitle("TagSettings.ShareButton".localized(), for: .normal)
        networkOwnerLabel.text = "TagSettings.NetworkInfo.Owner".localized()

        tableView.reloadData()
    }

    func showTagRemovalConfirmationDialog() {
        let title = "TagSettings.confirmTagRemovalDialog.title".localized()
        let message = "TagSettings.confirmTagRemovalDialog.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(),
                                           style: .destructive,
                                           handler: { [weak self] _ in
                                            self?.output.viewDidConfirmTagRemoval()
                                           }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showMacAddressDetail() {
        let title = "TagSettings.Mac.Alert.title".localized()
        let controller = UIAlertController(title: title, message: viewModel?.mac.value, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Copy".localized(), style: .default, handler: { [weak self] _ in
            if let mac = self?.viewModel?.mac.value {
                UIPasteboard.general.string = mac
            }
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showUUIDDetail() {
        let title = "TagSettings.UUID.Alert.title".localized()
        let controller = UIAlertController(title: title, message: viewModel?.uuid.value, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Copy".localized(), style: .default, handler: { [weak self] _ in
            if let uuid = self?.viewModel?.uuid.value {
                UIPasteboard.general.string = uuid
            }
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showUpdateFirmwareDialog() {
        let title = "TagSettings.UpdateFirmware.Alert.title".localized()
        let message = "TagSettings.UpdateFirmware.Alert.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionTitle = "TagSettings.UpdateFirmware.Alert.Buttons.LearnMore.title".localized()
        controller.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidAskToLearnMoreAboutFirmwareUpdate()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showHumidityIsClippedDialog() {
        let title = "TagSettings.HumidityIsClipped.Alert.title".localized()
        let message = "TagSettings.HumidityIsClipped.Alert.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionTitle = "TagSettings.HumidityIsClipped.Alert.Fix.button".localized()
        controller.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidAskToFixHumidityAdjustment()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showBothNotConnectedAndNoPNPermissionDialog() {
        let message = "TagSettings.AlertsAreDisabled.Dialog.BothNotConnectedAndNoPNPermission.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionTitle = "TagSettings.AlertsAreDisabled.Dialog.Connect.title".localized()
        controller.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidAskToConnectFromAlertsDisabledDialog()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showNotConnectedDialog() {
        let message = "TagSettings.AlertsAreDisabled.Dialog.NotConnected.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionTitle = "TagSettings.AlertsAreDisabled.Dialog.Connect.title".localized()
        controller.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidAskToConnectFromAlertsDisabledDialog()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

// MARK: - View lifecycle
extension TagSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        configureViews()
        bindViewModels()
        updateUI()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
}

// MARK: - IBActions
extension TagSettingsTableViewController {
    @IBAction func dismissBarButtonItemAction(_ sender: Any) {
        output.viewDidAskToDismiss()
    }

    @IBAction func removeThisRuuviTagButtonTouchUpInside(_ sender: Any) {
        playImpact()
        output.viewDidAskToRemoveRuuviTag()
    }

    @IBAction func randomizeBackgroundButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToRandomizeBackground()
    }

    @IBAction func selectBackgroundButtonTouchUpInside(_ sender: UIButton) {
        output.viewDidAskToSelectBackground(sourceView: sender)
    }

    @IBAction func tagNameTextFieldEditingDidEnd(_ sender: Any) {
        if let name = tagNameTextField.text {
            output.viewDidChangeTag(name: name)
        }
    }

    @IBAction func keepConnectionSwitchValueChanged(_ sender: Any) {
        viewModel?.keepConnection.value = keepConnectionSwitch.isOn
    }

    @IBAction func didTapClaimButton(_ sender: UIButton) {
        playImpact()
        output.viewDidTapClaimButton()
    }

    @IBAction func didTapShareButton(_ sender: UIButton) {
        playImpact()
        output.viewDidTapShareButton()
    }

    private func playImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - UITableViewDelegate
extension TagSettingsTableViewController {
    // swiftlint:disable cyclomatic_complexity
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        switch cell {
        case tagNameCell:
            tagNameTextField.becomeFirstResponder()
        case macAddressCell:
            output.viewDidTapOnMacAddress()
        case uuidCell:
            output.viewDidTapOnUUID()
        case txPowerCell:
            output.viewDidTapOnTxPower()
        case msnCell:
            output.viewDidTapOnMeasurementSequenceNumber()
        case temperatureOffsetCorrectionCell:
            output.viewDidTapTemperatureOffsetCorrection()
        case humidityOffsetCorrectionCell:
            output.viewDidTapHumidityOffsetCorrection()
        case pressureOffsetCorrectionCell:
            output.viewDidTapOnPressureOffsetCorrection()
        case updateFirmwareCell:
            output.viewDidTapOnUpdateFirmware()
        default:
            break
        }
    }
    // swiftlint:enable cyclomatic_complexity

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = TagSettingsTableSection.section(for: section)
        switch section {
        case .name:
            return "TagSettings.SectionHeader.Name.title".localized()
        case .offsetCorrection:
            return "TagSettings.SectionHeader.OffsetCorrection.Title".localized()
        case .connection:
            return TagSettingsTableSection.showConnection(for: viewModel)
                ? "TagSettings.SectionHeader.Connection.title".localized() : nil
        case .networkInfo:
            return TagSettingsTableSection.showNetworkInfo(for: viewModel)
                ? "TagSettings.SectionHeader.NetworkInfo.title".localized() : nil
        case .firmware:
            return TagSettingsTableSection.showUpdateFirmware(for: viewModel)
                ? "TagSettings.SectionHeader.Firmware.title".localized() : nil
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = TagSettingsTableSection.section(for: section)
        switch section {
        case .moreInfo:
            // swiftlint:disable force_cast
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: moreInfoSectionHeaderReuseIdentifier)
                as! TagSettingsMoreInfoHeaderFooterView
            // swiftlint:enable force_cast
            header.delegate = self
            header.noValuesView.isHidden = viewModel?.version.value == 5
            return header
        case .alerts:
            // swiftlint:disable force_cast
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: alertsSectionHeaderReuseIdentifier)
                as! TagSettingsAlertsHeaderFooterView
            // swiftlint:enable force_cast
            header.delegate = self
            header.disabledView.isHidden = viewModel?.isPNAlertsAvailiable.value ?? false
            return header
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let s = TagSettingsTableSection.section(for: section)
        switch s {
        case .moreInfo:
            return 44
        case .alerts:
            return TagSettingsTableSection.showAlerts(for: viewModel) ? 44 : .leastNormalMagnitude
        case .connection:
            return TagSettingsTableSection.showConnection(for: viewModel)
                ? super.tableView(tableView, heightForHeaderInSection: section) : .leastNormalMagnitude
        case .networkInfo:
            return TagSettingsTableSection.showNetworkInfo(for: viewModel)
                ? 44 : .leastNormalMagnitude
        case .firmware:
            return TagSettingsTableSection.showUpdateFirmware(for: viewModel)
                ? 44 : .leastNormalMagnitude
        default:
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let s = TagSettingsTableSection.section(for: section)
        switch s {
        case .alerts:
            return TagSettingsTableSection.showAlerts(for: viewModel)
                ? super.tableView(tableView, heightForHeaderInSection: section) : .leastNormalMagnitude
        case .connection:
            return TagSettingsTableSection.showConnection(for: viewModel)
                ? super.tableView(tableView, heightForHeaderInSection: section) : .leastNormalMagnitude
        default:
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let s = TagSettingsTableSection.section(for: section)
        switch s {
        case .alerts:
            return TagSettingsTableSection.showAlerts(for: viewModel)
                ? super.tableView(tableView, numberOfRowsInSection: section) : 0
        case .connection:
            return TagSettingsTableSection.showConnection(for: viewModel)
                ? super.tableView(tableView, numberOfRowsInSection: section) : 0

        case .networkInfo:
            return TagSettingsTableSection.showNetworkInfo(for: viewModel)
                ? super.tableView(tableView, numberOfRowsInSection: section) : 0
        case .firmware:
            return TagSettingsTableSection.showUpdateFirmware(for: viewModel)
                ? super.tableView(tableView, numberOfRowsInSection: section) : 0
        default:
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if viewModel?.isAlertsEnabled.value == true {
            let headerHeight: CGFloat = 66
            let controlsHeight: CGFloat = 148
            let descriptionHeight: CGFloat = 60
            switch cell {
            case temperatureAlertHeaderCell,
                 rhAlertHeaderCell,
                 humidityAlertHeaderCell,
                 dewPointAlertHeaderCell,
                 pressureAlertHeaderCell,
                 connectionAlertHeaderCell,
                 movementAlertHeaderCell:
                return headerHeight
            case temperatureAlertControlsCell:
                return (viewModel?.isTemperatureAlertOn.value ?? false) ? controlsHeight : 0
            case humidityAlertControlsCell:
                return (viewModel?.isHumidityAlertOn.value ?? false) ? controlsHeight : 0
            case rhAlertControlsCell:
                return (viewModel?.isRelativeHumidityAlertOn.value ?? false) ? controlsHeight : 0
            case dewPointAlertControlsCell:
                return (viewModel?.isDewPointAlertOn.value ?? false) ? controlsHeight : 0
            case pressureAlertControlsCell:
                return (viewModel?.isPressureAlertOn.value ?? false) ? controlsHeight : 0
            case connectionAlertDescriptionCell:
                return (viewModel?.isConnectionAlertOn.value ?? false) ? descriptionHeight : 0
            case movementAlertDescriptionCell:
                return (viewModel?.isMovementAlertOn.value ?? false) ? descriptionHeight : 0
            default:
                return 44
            }
        } else {
            switch cell {
            case temperatureAlertHeaderCell,
                 temperatureAlertControlsCell,
                 humidityAlertHeaderCell,
                 rhAlertHeaderCell,
                 humidityAlertControlsCell,
                 rhAlertControlsCell,
                 dewPointAlertHeaderCell,
                 dewPointAlertControlsCell,
                 pressureAlertHeaderCell,
                 pressureAlertControlsCell,
                 connectionAlertHeaderCell,
                 connectionAlertDescriptionCell,
                 movementAlertHeaderCell,
                 movementAlertDescriptionCell:
                return 0
            default:
                return 44
            }
        }
    }
}

// MARK: - TagSettingsAlertsHeaderFooterViewDelegate
extension TagSettingsTableViewController: TagSettingsAlertsHeaderFooterViewDelegate {
    func tagSettingsAlerts(headerView: TagSettingsAlertsHeaderFooterView, didTapOnDisabled button: UIButton) {
        output.viewDidTapOnAlertsDisabledView()
    }
}

// MARK: - TagSettingsMoreInfoHeaderFooterViewDelegate
extension TagSettingsTableViewController: TagSettingsMoreInfoHeaderFooterViewDelegate {
    func tagSettingsMoreInfo(headerView: TagSettingsMoreInfoHeaderFooterView, didTapOnInfo button: UIButton) {
        output.viewDidTapOnNoValuesView()
    }
}

// MARK: - TagSettingsAlertHeaderCellDelegate
extension TagSettingsTableViewController: TagSettingsAlertHeaderCellDelegate {
    func tagSettingsAlertHeader(cell: TagSettingsAlertHeaderCell, didToggle isOn: Bool) {
        switch cell {
        case temperatureAlertHeaderCell:
            viewModel?.isTemperatureAlertOn.value = isOn
        case humidityAlertHeaderCell:
            viewModel?.isHumidityAlertOn.value = isOn
        case rhAlertHeaderCell:
            viewModel?.isRelativeHumidityAlertOn.value = isOn
        case dewPointAlertHeaderCell:
            viewModel?.isDewPointAlertOn.value = isOn
        case pressureAlertHeaderCell:
            viewModel?.isPressureAlertOn.value = isOn
        case connectionAlertHeaderCell:
            viewModel?.isConnectionAlertOn.value = isOn
        case movementAlertHeaderCell:
            viewModel?.isMovementAlertOn.value = isOn
        default:
            break
        }
    }
}

// MARK: - TagSettingsAlertDescriptionCellDelegate
extension TagSettingsTableViewController: TagSettingsAlertDescriptionCellDelegate {
    func tagSettingsAlertDescription(cell: TagSettingsAlertDescriptionCell, didEnter description: String?) {
        switch cell {
        case connectionAlertDescriptionCell:
            viewModel?.connectionAlertDescription.value = description
        case movementAlertDescriptionCell:
            viewModel?.movementAlertDescription.value = description
        default:
            break
        }
    }
}

// MARK: - TagSettingsAlertControlsCellDelegate
extension TagSettingsTableViewController: TagSettingsAlertControlsCellDelegate {
    func tagSettingsAlertControls(cell: TagSettingsAlertControlsCell, didEnter description: String?) {
        switch cell {
        case temperatureAlertControlsCell:
            viewModel?.temperatureAlertDescription.value = description
        case humidityAlertControlsCell:
            viewModel?.humidityAlertDescription.value = description
        case rhAlertControlsCell:
            viewModel?.relativeHumidityAlertDescription.value = description
        case dewPointAlertControlsCell:
            viewModel?.dewPointAlertDescription.value = description
        case pressureAlertControlsCell:
            viewModel?.pressureAlertDescription.value = description
        default:
            break
        }
    }

    func tagSettingsAlertControls(cell: TagSettingsAlertControlsCell, didSlideTo minValue: CGFloat, maxValue: CGFloat) {
        switch cell {
        case temperatureAlertControlsCell:
            if let tu = viewModel?.temperatureUnit.value {
                viewModel?.temperatureLowerBound.value = Temperature(Double(minValue), unit: tu.unitTemperature)
                viewModel?.temperatureUpperBound.value = Temperature(Double(maxValue), unit: tu.unitTemperature)
            }
        case rhAlertControlsCell:
            viewModel?.relativeHumidityLowerBound.value = Double(minValue)
            viewModel?.relativeHumidityUpperBound.value = Double(maxValue)
        case humidityAlertControlsCell:
            viewModel?.humidityLowerBound.value = Humidity(value: Double(minValue), unit: .absolute)
            viewModel?.humidityUpperBound.value = Humidity(value: Double(maxValue), unit: .absolute)
        case dewPointAlertControlsCell:
            if let tu = viewModel?.temperatureUnit.value {
                viewModel?.dewPointLowerBound.value = Temperature(Double(minValue), unit: tu.unitTemperature)
                viewModel?.dewPointUpperBound.value = Temperature(Double(maxValue), unit: tu.unitTemperature)
            }
        case pressureAlertControlsCell:
            if let pu = viewModel?.pressureUnit.value {
                viewModel?.pressureLowerBound.value = Pressure(Double(minValue), unit: pu)
                viewModel?.pressureUpperBound.value = Pressure(Double(maxValue), unit: pu)
            }
        default:
            break
        }
    }
}

// MARK: - View configuration
extension TagSettingsTableViewController {
    private func configureViews() {
        let moreInfoSectionNib = UINib(nibName: "TagSettingsMoreInfoHeaderFooterView", bundle: nil)
        tableView.register(moreInfoSectionNib, forHeaderFooterViewReuseIdentifier: moreInfoSectionHeaderReuseIdentifier)
        let alertsSectionNib = UINib(nibName: "TagSettingsAlertsHeaderFooterView", bundle: nil)
        tableView.register(alertsSectionNib, forHeaderFooterViewReuseIdentifier: alertsSectionHeaderReuseIdentifier)
        temperatureAlertHeaderCell.delegate = self
        temperatureAlertControlsCell.delegate = self
        humidityAlertHeaderCell.delegate = self
        rhAlertHeaderCell.delegate = self
        humidityAlertControlsCell.delegate = self
        rhAlertControlsCell.delegate = self
        dewPointAlertHeaderCell.delegate = self
        dewPointAlertControlsCell.delegate = self
        pressureAlertHeaderCell.delegate = self
        pressureAlertControlsCell.delegate = self
        connectionAlertHeaderCell.delegate = self
        connectionAlertDescriptionCell.delegate = self
        movementAlertHeaderCell.delegate = self
        movementAlertDescriptionCell.delegate = self
        configureMinMaxForSliders()
        addGestureRecognizerOnUploadBackgroundIndicatorView()
    }

    private func addGestureRecognizerOnUploadBackgroundIndicatorView() {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(Self.uploadBackgroundIndicatorViewTapHandler(_:))
        )
        uploadBackgroundIndicatorView.addGestureRecognizer(tap)
    }

    @objc
    private func uploadBackgroundIndicatorViewTapHandler(_ sender: Any) {
        output.viewDidTapOnBackgroundIndicator()
    }

    private func configureMinMaxForSliders() {
        let tu = viewModel?.temperatureUnit.value ?? .celsius
        temperatureAlertControlsCell.slider.minValue = CGFloat(tu.alertRange.lowerBound)
        temperatureAlertControlsCell.slider.maxValue = CGFloat(tu.alertRange.upperBound)

        let hu = HumidityUnit.gm3
        humidityAlertControlsCell.slider.minValue = CGFloat(hu.alertRange.lowerBound)
        humidityAlertControlsCell.slider.maxValue = CGFloat(hu.alertRange.upperBound)

        let rhRange = HumidityUnit.percent.alertRange
        rhAlertControlsCell.slider.minValue = CGFloat(rhRange.lowerBound)
        rhAlertControlsCell.slider.maxValue = CGFloat(rhRange.upperBound)

        let p = viewModel?.pressureUnit.value ?? .hectopascals
        pressureAlertControlsCell.slider.minValue = CGFloat(p.alertRange.lowerBound)
        pressureAlertControlsCell.slider.maxValue = CGFloat(p.alertRange.upperBound)

        dewPointAlertControlsCell.slider.minValue = CGFloat(tu.alertRange.lowerBound)
        dewPointAlertControlsCell.slider.maxValue = CGFloat(tu.alertRange.upperBound)
    }
}

// MARK: - Bindings
extension TagSettingsTableViewController {
    private func bindViewModels() {
        bindViewModel()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func bindViewModel() {
        bindTemperatureAlertCells()
        bindRhAlertCells()
        bindHumidityAlertCells()
        bindDewPointAlertCells()
        bindPressureAlertCells()
        bindConnectionAlertCells()
        bindMovementAlertCell()
        bindTagNetworkActions()

        guard isViewLoaded, let viewModel = viewModel else { return }

        footerView.bind(viewModel.isAuthorized,
                        block: { (footerView, isAuthorized) in
            if isAuthorized == true {
                let size: CGSize = CGSize(width: footerView.frame.width,
                                          height: 145)
                footerView.frame = CGRect(origin: footerView.frame.origin,
                                          size: size)
            } else {
                let size: CGSize = CGSize(width: footerView.frame.width,
                                          height: 82)
                footerView.frame = CGRect(origin: footerView.frame.origin,
                                          size: size)
            }
        })

        dataSourceValueLabel.bind(viewModel.source) { label, source in
            if let source = source {
                switch source {
                case .unknown:
                    label.text = "N/A".localized()
                case .advertisement:
                    label.text = "TagSettings.DataSource.Advertisement.title".localized()
                case .heartbeat:
                    label.text = "TagSettings.DataSource.Heartbeat.title".localized()
                case .log:
                    label.text = "TagSettings.DataSource.Heartbeat.title".localized()
                case .ruuviNetwork:
                    label.text = "TagSettings.DataSource.Network.title".localized()
                case .weatherProvider:
                    label.text = "N/A".localized()
                }
            } else {
                label.text = "N/A".localized()
            }
        }

        tableView.bind(viewModel.version) { (tableView, _) in
            tableView.reloadData()
        }

        tableView.bind(viewModel.humidityUnit) { tableView, _ in
            tableView.reloadData()
        }

        backgroundImageView.bind(viewModel.background) { $0.image = $1 }
        uploadBackgroundIndicatorView.bind(viewModel.isUploadingBackground) { v, isUploading in
            if let isUploading = isUploading {
                v.isHidden = !isUploading
            } else {
                v.isHidden = true
            }
        }
        uploadBackgroundProgressLabel.bind(viewModel.uploadingBackgroundPercentage) { lb, percentage in
            if let percentage = percentage {
                lb.text = String(format: "%.2f%@", percentage * 100.0, "%")
            }
        }
        tagNameTextField.bind(viewModel.name) { $0.text = $1 }

        let emptyValueString = "TagSettings.EmptyValue.sign"

        uuidValueLabel.bind(viewModel.uuid) { label, uuid in
            if let uuid = uuid {
                label.text = uuid
            } else {
                label.text = emptyValueString.localized()
            }
        }

        macAddressValueLabel.bind(viewModel.mac) { label, mac in
            if let mac = mac {
                label.text = mac
            } else {
                label.text = emptyValueString.localized()
            }
        }

        rssiValueLabel.bind(viewModel.rssi) { label, rssi in
            if let rssi = rssi {
                label.text = "\(rssi)"
            } else {
                label.text = emptyValueString.localized()
            }
        }

        voltageValueLabel.bind(viewModel.voltage) { label, voltage in
            if let voltage = voltage {
                label.text = String.localizedStringWithFormat("%.3f", voltage) + " " + "V".localized()
            } else {
                label.text = emptyValueString.localized()
            }
        }

        accelerationXValueLabel.bind(viewModel.accelerationX) { label, accelerationX in
            if let accelerationX = accelerationX {
                label.text = String.localizedStringWithFormat("%.3f", accelerationX) + " " + "g".localized()
            } else {
                label.text = emptyValueString.localized()
            }
        }

        accelerationYValueLabel.bind(viewModel.accelerationY) { label, accelerationY in
            if let accelerationY = accelerationY {
                label.text = String.localizedStringWithFormat("%.3f", accelerationY) + " " + "g".localized()
            } else {
                label.text = emptyValueString.localized()
            }
        }

        accelerationZValueLabel.bind(viewModel.accelerationZ) { label, accelerationZ in
            if let accelerationZ = accelerationZ {
                label.text = String.localizedStringWithFormat("%.3f", accelerationZ) + " " + "g".localized()
            } else {
                label.text = emptyValueString.localized()
            }
        }

        dataFormatValueLabel.bind(viewModel.version) { (label, version) in
            if let version = version {
                label.text = "\(version)"
            } else {
                label.text = emptyValueString.localized()
            }
        }

        msnValueLabel.bind(viewModel.measurementSequenceNumber) { (label, msn) in
            if let msn = msn {
                label.text = "\(msn)"
            } else {
                label.text = emptyValueString.localized()
            }
        }

        txPowerValueLabel.bind(viewModel.txPower) { (label, txPower) in
            if let txPower = txPower {
                label.text = "\(txPower)" + " " + "dBm".localized()
            } else {
                label.text = emptyValueString.localized()
            }
        }

        networkOwnerValueLabel.bind(viewModel.owner) { (label, owner) in
            label.text = owner
        }

        tableView.bind(viewModel.isConnectable) { (tableView, _) in
            tableView.reloadData()
        }

        tableView.bind(viewModel.isConnected) { (tableView, _) in
            tableView.reloadData()
        }

        tableView.bind(viewModel.isPushNotificationsEnabled) { (tableView, _) in
            tableView.reloadData()
        }

        tableView.bind(viewModel.isAlertsEnabled) { tableView, _ in
            tableView.reloadData()
        }

        let keepConnection = viewModel.keepConnection
        connectStatusLabel.bind(viewModel.isConnected) { [weak keepConnection] (label, isConnected) in
            let keep = keepConnection?.value ?? false
            if isConnected.bound {
                label.text = "TagSettings.ConnectStatus.Connected".localized()
            } else if keep {
                label.text = "TagSettings.ConnectStatus.Connecting".localized()
            } else {
                label.text = "TagSettings.ConnectStatus.Disconnected".localized()
            }
        }

        let isConnected = viewModel.isConnected

        keepConnectionSwitch.bind(viewModel.keepConnection) { (view, keepConnection) in
            view.isOn = keepConnection.bound
        }

        connectStatusLabel.bind(viewModel.keepConnection) { [weak isConnected] (label, keepConnection) in
            let isConnected = isConnected?.value ?? false
            if isConnected {
                label.text = "TagSettings.ConnectStatus.Connected".localized()
            } else if keepConnection.bound {
                label.text = "TagSettings.ConnectStatus.Connecting".localized()
            } else {
                label.text = "TagSettings.ConnectStatus.Disconnected".localized()
            }
        }

        bindOffsetCorrectionCells()
    }

    // swiftlint:disable:next function_body_length
    private func bindTemperatureAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
        temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isTemperatureAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }
        temperatureAlertHeaderCell.mutedTillLabel.bind(viewModel.temperatureAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                label.text = formatter.string(from: date)
            } else {
                label.isHidden = true
            }
        }
        temperatureAlertHeaderCell.mutedTillImageView.bind(viewModel.temperatureAlertMutedTill) { (imageView, date) in
            if let date = date, date > Date() {
                imageView.isHidden = false
            } else {
                imageView.isHidden = true
            }
        }

        temperatureAlertControlsCell.slider.bind(viewModel.isTemperatureAlertOn) { (slider, isOn) in
            slider.isEnabled = isOn.bound
        }

        temperatureAlertControlsCell.slider.bind(viewModel.temperatureLowerBound) { [weak self] (_, _) in
            self?.updateUITemperatureLowerBound()
            self?.updateUITemperatureAlertDescription()
        }
        temperatureAlertControlsCell.slider.bind(viewModel.temperatureUpperBound) { [weak self] (_, _) in
            self?.updateUITemperatureUpperBound()
            self?.updateUITemperatureAlertDescription()
        }

        temperatureAlertHeaderCell.titleLabel.bind(viewModel.temperatureUnit) { (label, temperatureUnit) in
            let title = "TagSettings.temperatureAlertTitleLabel.text"
            label.text = String(format: title.localized(), temperatureUnit?.symbol ?? "N/A".localized())
        }

        temperatureAlertControlsCell.slider.bind(viewModel.temperatureUnit) { (slider, temperatureUnit) in
            if let tu = temperatureUnit {
                slider.minValue = CGFloat(tu.alertRange.lowerBound)
                slider.maxValue = CGFloat(tu.alertRange.upperBound)
            }
        }

        temperatureAlertHeaderCell.descriptionLabel.bind(viewModel.isTemperatureAlertOn) { [weak self] (_, _) in
            self?.updateUITemperatureAlertDescription()
        }

        let isTemperatureAlertOn = viewModel.isTemperatureAlertOn

        temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isAlertsEnabled) { view, isAlertsEnabled in
            let isEnabled = isAlertsEnabled ?? false
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        temperatureAlertControlsCell.slider.bind(viewModel.isAlertsEnabled) {
            [weak isTemperatureAlertOn] slider, isAlertsEnabled in
            let isAe = isAlertsEnabled ?? false
            let isOn = isTemperatureAlertOn?.value ?? false
            slider.isEnabled = isOn && isAe
        }

        temperatureAlertControlsCell.textField.bind(viewModel.temperatureAlertDescription) {
            (textField, temperatureAlertDescription) in
            textField.text = temperatureAlertDescription
        }

        tableView.bind(viewModel.isTemperatureAlertOn) { tableView, _ in
            if tableView.window != nil {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

    private func bindConnectionAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
        connectionAlertHeaderCell.isOnSwitch.bind(viewModel.isConnectionAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        connectionAlertHeaderCell.mutedTillLabel.bind(viewModel.connectionAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                label.text = formatter.string(from: date)
            } else {
                label.isHidden = true
            }
        }
        connectionAlertHeaderCell.mutedTillImageView.bind(viewModel.connectionAlertMutedTill) { (imageView, date) in
            if let date = date, date > Date() {
                imageView.isHidden = false
            } else {
                imageView.isHidden = true
            }
        }

        connectionAlertHeaderCell.descriptionLabel.bind(viewModel.isConnectionAlertOn) { [weak self] (_, _) in
            self?.updateUIConnectionAlertDescription()
        }

        connectionAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
            view, isPushNotificationsEnabled in
            let isPN = isPushNotificationsEnabled ?? false
            let isEnabled = isPN
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        connectionAlertDescriptionCell.textField.bind(viewModel.connectionAlertDescription) {
            (textField, connectionAlertDescription) in
            textField.text = connectionAlertDescription
        }

        tableView.bind(viewModel.isConnectionAlertOn) { tableView, _ in
            if tableView.window != nil {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

    private func bindMovementAlertCell() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
        movementAlertHeaderCell.isOnSwitch.bind(viewModel.isMovementAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        movementAlertHeaderCell.mutedTillLabel.bind(viewModel.movementAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                label.text = formatter.string(from: date)
            } else {
                label.isHidden = true
            }
        }
        movementAlertHeaderCell.mutedTillImageView.bind(viewModel.movementAlertMutedTill) { (imageView, date) in
            if let date = date, date > Date() {
                imageView.isHidden = false
            } else {
                imageView.isHidden = true
            }
        }

        movementAlertHeaderCell.descriptionLabel.bind(viewModel.isMovementAlertOn) { [weak self] (_, _) in
            self?.updateUIMovementAlertDescription()
        }

        movementAlertHeaderCell.isOnSwitch.bind(viewModel.isAlertsEnabled) { view, isAlertsEnabled in
            let isEnabled = isAlertsEnabled ?? false
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        movementAlertDescriptionCell.textField.bind(viewModel.movementAlertDescription) {
            (textField, movementAlertDescription) in
            textField.text = movementAlertDescription
        }

        tableView.bind(viewModel.isMovementAlertOn) { tableView, _ in
            if tableView.window != nil {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindPressureAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
        pressureAlertHeaderCell.isOnSwitch.bind(viewModel.isPressureAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        pressureAlertHeaderCell.mutedTillLabel.bind(viewModel.pressureAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                label.text = formatter.string(from: date)
            } else {
                label.isHidden = true
            }
        }
        pressureAlertHeaderCell.mutedTillImageView.bind(viewModel.pressureAlertMutedTill) { (imageView, date) in
            if let date = date, date > Date() {
                imageView.isHidden = false
            } else {
                imageView.isHidden = true
            }
        }

        pressureAlertControlsCell.slider.bind(viewModel.isPressureAlertOn) { (slider, isOn) in
            slider.isEnabled = isOn.bound
        }

        pressureAlertControlsCell.slider.bind(viewModel.pressureLowerBound) { [weak self] (_, _) in
            self?.updateUIPressureLowerBound()
            self?.updateUIPressureAlertDescription()
        }

        pressureAlertControlsCell.slider.bind(viewModel.pressureUpperBound) { [weak self] (_, _) in
            self?.updateUIPressureUpperBound()
            self?.updateUIPressureAlertDescription()
        }

        pressureAlertHeaderCell.titleLabel.bind(viewModel.pressureUnit) { (label, pressureUnit) in
            let title = "TagSettings.PressureAlert.title"
            label.text = String(format: title.localized(), pressureUnit?.symbol ?? "N/A".localized())
        }

        pressureAlertControlsCell.slider.bind(viewModel.pressureUnit) { (slider, pressureUnit) in
            if let pu = pressureUnit {
                slider.minValue = CGFloat(pu.alertRange.lowerBound)
                slider.maxValue = CGFloat(pu.alertRange.upperBound)
            }
        }

        pressureAlertHeaderCell.descriptionLabel.bind(viewModel.isPressureAlertOn) { [weak self] (_, _) in
            self?.updateUIPressureAlertDescription()
        }

        let isPressureAlertOn = viewModel.isPressureAlertOn

        pressureAlertHeaderCell.isOnSwitch.bind(viewModel.isAlertsEnabled) { view, isAlertsEnabled in
            let isEnabled = isAlertsEnabled ?? false
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        pressureAlertControlsCell.slider.bind(viewModel.isAlertsEnabled) {
            [weak isPressureAlertOn] slider, isAlertsEnabled in
            let isAe = isAlertsEnabled ?? false
            let isOn = isPressureAlertOn?.value ?? false
            slider.isEnabled = isOn && isAe
        }

        pressureAlertControlsCell.textField.bind(viewModel.pressureAlertDescription) {
            (textField, pressureAlertDescription) in
            textField.text = pressureAlertDescription
        }

        tableView.bind(viewModel.isPressureAlertOn) { tableView, _ in
            if tableView.window != nil {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindRhAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
        rhAlertHeaderCell.isOnSwitch.bind(viewModel.isRelativeHumidityAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        rhAlertHeaderCell.mutedTillLabel.bind(viewModel.relativeHumidityAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                label.text = formatter.string(from: date)
            } else {
                label.isHidden = true
            }
        }
        rhAlertHeaderCell.mutedTillImageView.bind(viewModel.relativeHumidityAlertMutedTill) { (imageView, date) in
            if let date = date, date > Date() {
                imageView.isHidden = false
            } else {
                imageView.isHidden = true
            }
        }

        rhAlertControlsCell.slider.bind(viewModel.isRelativeHumidityAlertOn) { (slider, isOn) in
            slider.isEnabled = isOn.bound
        }

        rhAlertControlsCell.slider.bind(viewModel.relativeHumidityLowerBound) { [weak self] (_, _) in
            self?.updateUIRhLowerBound()
            self?.updateUIRhAlertDescription()
        }

        rhAlertControlsCell.slider.bind(viewModel.relativeHumidityUpperBound) { [weak self] (_, _) in
            self?.updateUIRhUpperBound()
            self?.updateUIRhAlertDescription()
        }

        rhAlertHeaderCell.titleLabel.bind(viewModel.humidityUnit) { (label, _) in
            let title = "TagSettings.AirHumidityAlert.title"
            let symbol = HumidityUnit.percent.symbol
            label.text = String(format: title.localized(), symbol)
        }

        rhAlertControlsCell.slider.bind(viewModel.humidityUnit) { (slider, _) in
            let hu = HumidityUnit.percent
            slider.minValue = CGFloat(hu.alertRange.lowerBound)
            slider.maxValue = CGFloat(hu.alertRange.upperBound)
        }

        rhAlertHeaderCell.descriptionLabel.bind(viewModel.isRelativeHumidityAlertOn) {
            [weak self] (_, _) in
            self?.updateUIRhAlertDescription()
        }

        let isRhAlertOn = viewModel.isRelativeHumidityAlertOn

        rhAlertHeaderCell.isOnSwitch.bind(viewModel.isAlertsEnabled) {
            view, isAlertsEnabled in
            let isEnabled = isAlertsEnabled ?? false
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        rhAlertControlsCell.slider.bind(viewModel.isAlertsEnabled) {
            [weak isRhAlertOn] slider, isAlertsEnabled in
            let isAe = isAlertsEnabled ?? false
            let isOn = isRhAlertOn?.value ?? false
            slider.isEnabled = isOn && isAe
        }

        rhAlertControlsCell.textField.bind(viewModel.relativeHumidityAlertDescription) {
            (textField, humidityAlertDescription) in
            textField.text = humidityAlertDescription
        }

        tableView.bind(viewModel.isRelativeHumidityAlertOn) { tableView, _ in
            if tableView.window != nil {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindHumidityAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
        humidityAlertHeaderCell.isOnSwitch.bind(viewModel.isHumidityAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        humidityAlertHeaderCell.mutedTillLabel.bind(viewModel.humidityAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                label.text = formatter.string(from: date)
            } else {
                label.isHidden = true
            }
        }
        humidityAlertHeaderCell.mutedTillImageView.bind(viewModel.humidityAlertMutedTill) { (imageView, date) in
            if let date = date, date > Date() {
                imageView.isHidden = false
            } else {
                imageView.isHidden = true
            }
        }

        humidityAlertControlsCell.slider.bind(viewModel.isHumidityAlertOn) { (slider, isOn) in
            slider.isEnabled = isOn.bound
        }

        humidityAlertControlsCell.slider.bind(viewModel.humidityLowerBound) { [weak self] (_, _) in
            self?.updateUIHumidityLowerBound()
            self?.updateUIHumidityAlertDescription()
        }

        humidityAlertControlsCell.slider.bind(viewModel.humidityUpperBound) { [weak self] (_, _) in
            self?.updateUIHumidityUpperBound()
            self?.updateUIHumidityAlertDescription()
        }

        humidityAlertHeaderCell.titleLabel.bind(viewModel.humidityUnit) { (label, _) in
            let title = "TagSettings.AirHumidityAlert.title"
            label.text = String(format: title.localized(), HumidityUnit.gm3.symbol)
        }

        humidityAlertControlsCell.slider.bind(viewModel.humidityUnit) { (slider, _) in
            let hu = HumidityUnit.gm3
            slider.minValue = CGFloat(hu.alertRange.lowerBound)
            slider.maxValue = CGFloat(hu.alertRange.upperBound)
        }

        humidityAlertHeaderCell.descriptionLabel.bind(viewModel.isHumidityAlertOn) {
            [weak self] (_, _) in
            self?.updateUIHumidityAlertDescription()
        }

        let isHumidityAlertOn = viewModel.isHumidityAlertOn

        humidityAlertHeaderCell.isOnSwitch.bind(viewModel.isPNAlertsAvailiable) { view, isPNAlertsAvailiable in
            let isEnabled = isPNAlertsAvailiable ?? false
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        humidityAlertControlsCell.slider.bind(viewModel.isPNAlertsAvailiable) {
            [weak isHumidityAlertOn] slider, isPNAlertsAvailiable in
            let isAe = isPNAlertsAvailiable ?? false
            let isOn = isHumidityAlertOn?.value ?? false
            slider.isEnabled = isOn && isAe
        }

        humidityAlertControlsCell.textField.bind(viewModel.humidityAlertDescription) {
            (textField, humidityAlertDescription) in
            textField.text = humidityAlertDescription
        }

        tableView.bind(viewModel.isHumidityAlertOn) { tableView, _ in
            if tableView.window != nil {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindDewPointAlertCells() {
        guard isViewLoaded, let viewModel = viewModel else {
            return
        }
        dewPointAlertHeaderCell.isOnSwitch.bind(viewModel.isDewPointAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        dewPointAlertHeaderCell.mutedTillLabel.bind(viewModel.dewPointAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                label.text = formatter.string(from: date)
            } else {
                label.isHidden = true
            }
        }
        dewPointAlertHeaderCell.mutedTillImageView.bind(viewModel.dewPointAlertMutedTill) { (imageView, date) in
            if let date = date, date > Date() {
                imageView.isHidden = false
            } else {
                imageView.isHidden = true
            }
        }

        dewPointAlertControlsCell.slider.bind(viewModel.isDewPointAlertOn) { (slider, isOn) in
            slider.isEnabled = isOn.bound
        }

        dewPointAlertControlsCell.slider.bind(viewModel.dewPointLowerBound) { [weak self] (_, _) in
            self?.updateUIDewPointCelsiusLowerBound()
            self?.updateUIDewPointAlertDescription()
        }

        dewPointAlertControlsCell.slider.bind(viewModel.dewPointUpperBound) { [weak self] (_, _) in
            self?.updateUIDewPointCelsiusUpperBound()
            self?.updateUIDewPointAlertDescription()
        }

        dewPointAlertHeaderCell.titleLabel.bind(viewModel.temperatureUnit) { (label, temperatureUnit) in
            let title = "TagSettings.dewPointAlertTitleLabel.text"
            label.text = title.localized()
                + " "
                + (temperatureUnit?.symbol ?? "N/A".localized())
        }

        dewPointAlertControlsCell.slider.bind(viewModel.temperatureUnit) { (slider, temperatureUnit) in
            if let tu = temperatureUnit {
                slider.minValue = CGFloat(tu.alertRange.lowerBound)
                slider.maxValue = CGFloat(tu.alertRange.upperBound)
            }
        }

        dewPointAlertHeaderCell.descriptionLabel.bind(viewModel.isDewPointAlertOn) { [weak self] (_, _) in
            self?.updateUIDewPointAlertDescription()
        }

        let isDewPointAlertOn = viewModel.isDewPointAlertOn

        dewPointAlertHeaderCell.isOnSwitch.bind(viewModel.isPNAlertsAvailiable) { view, isPNAlertsAvailiable in
            let isEnabled = isPNAlertsAvailiable ?? false
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        dewPointAlertControlsCell.slider.bind(viewModel.isPNAlertsAvailiable) {
            [weak isDewPointAlertOn] slider, isPNAlertsAvailiable in
            let isAe = isPNAlertsAvailiable ?? false
            let isOn = isDewPointAlertOn?.value ?? false
            slider.isEnabled = isOn && isAe
        }

        dewPointAlertControlsCell.textField.bind(viewModel.dewPointAlertDescription) {
            (textField, dewPointAlertDescription) in
            textField.text = dewPointAlertDescription
        }

        tableView.bind(viewModel.isDewPointAlertOn) { tableView, _ in
            if tableView.window != nil {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

// MARK: - bind tag network actions
    func bindTagNetworkActions() {
        guard isViewLoaded, let viewModel = viewModel else {
            return
        }
        let enabledColor = UIColor(red: 21/255, green: 141/255, blue: 165/255, alpha: 1.0)
        let disabledColor = UIColor.gray
        networkTagActionsStackView.bind(viewModel.isAuthorized) { (stack, isAuthorized) in
            stack.isHidden = !(isAuthorized ?? false)
        }
        claimTagButton.bind(viewModel.canClaimTag) { (button, canClaimTag) in
            let canClaimTag: Bool = canClaimTag ?? false
            button.isEnabled = canClaimTag
            button.backgroundColor = canClaimTag ? enabledColor : disabledColor
        }
        shareTagButton.bind(viewModel.canShareTag) { (button, canShareTag) in
            let canShareTag: Bool = canShareTag ?? false
            button.isEnabled = canShareTag
            button.backgroundColor = canShareTag ? enabledColor : disabledColor
        }
        claimTagButton.bind(viewModel.isClaimedTag) { (button, isClaimedTag) in
                let title = isClaimedTag ?? false
                    ? "TagSettings.ClaimTagButton.Unclaim".localized()
                    : "TagSettings.ClaimTagButton.Claim".localized()
                button.setTitle(title, for: .normal)
        }
    }
    private func bindOffsetCorrectionCells() {
        guard isViewLoaded, let viewModel = viewModel else {
            return
        }

        temperatureOffsetValueLabel.bind(viewModel.temperatureOffsetCorrection) {[weak self] label, value in
            label.text = self?.measurementService.temperatureOffsetCorrectionString(for: value ?? 0)
        }

        humidityOffsetValueLabel.bind(viewModel.humidityOffsetCorrection) {[weak self] label, value in
            label.text = self?.measurementService.humidityOffsetCorrectionString(for: value ?? 0)
        }

        pressureOffsetValueLabel.bind(viewModel.pressureOffsetCorrection) {[weak self]  label, value in
            label.text = self?.measurementService.pressureOffsetCorrectionString(for: value ?? 0)
        }
    }
}

// MARK: - UITextFieldDelegate
extension TagSettingsTableViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: - Update UI
extension TagSettingsTableViewController {
    private func updateUI() {
        updateUITemperatureAlertDescription()
        updateUITemperatureLowerBound()
        updateUITemperatureUpperBound()

        updateUIHumidityAlertDescription()
        updateUIHumidityLowerBound()
        updateUIHumidityUpperBound()

        updateUIPressureAlertDescription()
        updateUIPressureLowerBound()
        updateUIPressureUpperBound()

        updateUIDewPointAlertDescription()
        updateUIDewPointCelsiusLowerBound()
        updateUIDewPointCelsiusUpperBound()
    }
    // MARK: - updateUITemperature

    private func updateUITemperatureLowerBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel?.temperatureUnit.value else {
            let range = TemperatureUnit.celsius.alertRange
            temperatureAlertControlsCell.slider.minValue = CGFloat(range.lowerBound)
            temperatureAlertControlsCell.slider.selectedMinValue = CGFloat(range.lowerBound)
            return
        }
        if let lower = viewModel?.temperatureLowerBound.value?.converted(to: temperatureUnit.unitTemperature) {
            temperatureAlertControlsCell.slider.selectedMinValue = CGFloat(lower.value)
        } else {
            let lower: CGFloat = CGFloat(temperatureUnit.alertRange.lowerBound)
            temperatureAlertControlsCell.slider.selectedMinValue = lower
        }
    }

    private func updateUITemperatureUpperBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel?.temperatureUnit.value else {
            let range = TemperatureUnit.celsius.alertRange
            temperatureAlertControlsCell.slider.maxValue = CGFloat(range.upperBound)
            temperatureAlertControlsCell.slider.selectedMaxValue = CGFloat(range.upperBound)
            return
        }
        if let upper = viewModel?.temperatureUpperBound.value?.converted(to: temperatureUnit.unitTemperature) {
            temperatureAlertControlsCell.slider.selectedMaxValue = CGFloat(upper.value)
        } else {
            let upper: CGFloat = CGFloat(temperatureUnit.alertRange.upperBound)
            temperatureAlertControlsCell.slider.selectedMaxValue = upper
        }
    }

    private func updateUITemperatureAlertDescription() {
        guard isViewLoaded else { return }
        guard viewModel?.isTemperatureAlertOn.value == true else {
            temperatureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            return
        }
        if let tu = viewModel?.temperatureUnit.value?.unitTemperature,
           let l = viewModel?.temperatureLowerBound.value?.converted(to: tu),
           let u = viewModel?.temperatureUpperBound.value?.converted(to: tu) {
            let format = "TagSettings.Alerts.Temperature.description".localized()
            temperatureAlertHeaderCell.descriptionLabel.text = String(format: format, l.value, u.value)
        } else {
            temperatureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }

    // MARK: - updateRh
    private func updateUIRhLowerBound() {
        guard isViewLoaded else { return }
        let range = HumidityUnit.percent.alertRange
        if let lower = viewModel?.relativeHumidityLowerBound.value {
            rhAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
        } else {
            rhAlertControlsCell.slider.selectedMinValue = CGFloat(range.lowerBound)
        }
    }

    private func updateUIRhUpperBound() {
        guard isViewLoaded else { return }
        let range = HumidityUnit.percent.alertRange
        if let upper = viewModel?.relativeHumidityUpperBound.value {
            rhAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
        } else {
            rhAlertControlsCell.slider.selectedMaxValue = CGFloat(range.upperBound)
        }
    }

    private func updateUIRhAlertDescription() {
        guard isViewLoaded else { return }
        guard viewModel?.isRelativeHumidityAlertOn.value == true else {
            rhAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            return
        }
        if let l = viewModel?.relativeHumidityLowerBound.value,
           let u = viewModel?.relativeHumidityUpperBound.value {
            let format = "TagSettings.Alerts.Humidity.description".localized()
            rhAlertHeaderCell.descriptionLabel.text = String(format: format, l, u)
        } else {
            rhAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }

    // MARK: - updateUIHumidity
    private func updateUIHumidityLowerBound() {
        guard isViewLoaded else { return }
        let hu = HumidityUnit.gm3
        if let lower = viewModel?.humidityLowerBound.value {
            let lowerAbsolute: Double = max(lower.converted(to: .absolute).value, hu.alertRange.lowerBound)
            humidityAlertControlsCell.slider.selectedMinValue = CGFloat(lowerAbsolute)
        } else {
            humidityAlertControlsCell.slider.selectedMinValue = CGFloat(hu.alertRange.lowerBound)
        }
    }

    private func updateUIHumidityUpperBound() {
        guard isViewLoaded else { return }
        let hu = HumidityUnit.gm3
        if let upper = viewModel?.humidityUpperBound.value {
            let upperAbsolute: Double = min(upper.converted(to: .absolute).value, hu.alertRange.upperBound)
            humidityAlertControlsCell.slider.selectedMaxValue = CGFloat(upperAbsolute)
        } else {
            humidityAlertControlsCell.slider.selectedMaxValue = CGFloat(hu.alertRange.upperBound)
        }
    }

    private func updateUIHumidityAlertDescription() {
        guard isViewLoaded else { return }
        guard let isHumidityAlertOn = viewModel?.isHumidityAlertOn.value,
              isHumidityAlertOn else {
            humidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            return
        }
        let hu = HumidityUnit.gm3
        if let l = viewModel?.humidityLowerBound.value,
           let u = viewModel?.humidityUpperBound.value {
            let format = "TagSettings.Alerts.Humidity.description".localized()
            let description: String
            let la: Double = max(l.converted(to: .absolute).value, hu.alertRange.lowerBound)
            let ua: Double = min(u.converted(to: .absolute).value, hu.alertRange.upperBound)
            description = String(format: format, la, ua)
            humidityAlertHeaderCell.descriptionLabel.text = description
        } else {
            humidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }

    // MARK: - updateUIPressure
    private func updateUIPressureLowerBound() {
        guard isViewLoaded else { return }
        guard let pu = viewModel?.pressureUnit.value else {
            let range = UnitPressure.hectopascals.alertRange
            pressureAlertControlsCell.slider.minValue = CGFloat(range.lowerBound)
            pressureAlertControlsCell.slider.selectedMinValue = CGFloat(range.lowerBound)
            return
        }
        if let lower = viewModel?.pressureLowerBound.value?.converted(to: pu).value {
            let l = min(
                max(lower, pu.alertRange.lowerBound),
                pu.alertRange.upperBound
            )
            pressureAlertControlsCell.slider.selectedMinValue = CGFloat(l)
        } else {
            pressureAlertControlsCell.slider.selectedMinValue = CGFloat(pu.alertRange.lowerBound)
        }
    }

    private func updateUIPressureUpperBound() {
        guard isViewLoaded else { return }
        guard let pu = viewModel?.pressureUnit.value else {
            let range = UnitPressure.hectopascals.alertRange
            pressureAlertControlsCell.slider.maxValue =  CGFloat(range.upperBound)
            pressureAlertControlsCell.slider.selectedMaxValue =  CGFloat(range.upperBound)
            return
        }
        if let upper = viewModel?.pressureUpperBound.value?.converted(to: pu).value {
            let u = max(
                min(upper, pu.alertRange.upperBound),
                pu.alertRange.lowerBound
            )
            pressureAlertControlsCell.slider.selectedMaxValue = CGFloat(u)
        } else {
            pressureAlertControlsCell.slider.selectedMaxValue = CGFloat(pu.alertRange.upperBound)
        }
    }

    private func updateUIPressureAlertDescription() {
        guard isViewLoaded else { return }
        guard let isPressureAlertOn = viewModel?.isPressureAlertOn.value,
              isPressureAlertOn else {
            pressureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            return
        }
        if let pu = viewModel?.pressureUnit.value,
           let lower = viewModel?.pressureLowerBound.value?.converted(to: pu).value,
           let upper = viewModel?.pressureUpperBound.value?.converted(to: pu).value {
            let l = min(
                max(lower, pu.alertRange.lowerBound),
                pu.alertRange.upperBound
            )
            let u = max(
                min(upper, pu.alertRange.upperBound),
                pu.alertRange.lowerBound
            )
            let format = "TagSettings.Alerts.Pressure.description".localized()
            pressureAlertHeaderCell.descriptionLabel.text = String(format: format, l, u)
        } else {
            pressureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }

    // MARK: updateUIDewPoint

    private func updateUIDewPointCelsiusLowerBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel?.temperatureUnit.value else {
            let range = TemperatureUnit.celsius.alertRange
            dewPointAlertControlsCell.slider.minValue = CGFloat(range.lowerBound)
            dewPointAlertControlsCell.slider.selectedMinValue = CGFloat(range.lowerBound)
            return
        }
        if let lower = viewModel?.dewPointLowerBound.value?.converted(to: temperatureUnit.unitTemperature) {
            dewPointAlertControlsCell.slider.selectedMinValue = CGFloat(lower.value)
        } else {
            let lower: CGFloat = CGFloat(temperatureUnit.alertRange.lowerBound)
            dewPointAlertControlsCell.slider.selectedMinValue = lower
        }
    }

    private func updateUIDewPointCelsiusUpperBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel?.temperatureUnit.value else {
            dewPointAlertControlsCell.slider.maxValue = CGFloat(TemperatureUnit.celsius.alertRange.upperBound)
            dewPointAlertControlsCell.slider.selectedMaxValue = CGFloat(TemperatureUnit.celsius.alertRange.upperBound)
            return
        }
        if let upper = viewModel?.dewPointUpperBound.value?.converted(to: temperatureUnit.unitTemperature) {
            dewPointAlertControlsCell.slider.selectedMaxValue = CGFloat(upper.value)
        } else {
            let upper: CGFloat = CGFloat(temperatureUnit.alertRange.upperBound)
            dewPointAlertControlsCell.slider.selectedMaxValue = upper
        }
    }

    private func updateUIDewPointAlertDescription() {
        guard isViewLoaded else { return }
        guard viewModel?.isDewPointAlertOn.value == true else {
            dewPointAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            return
        }
        if let tu = viewModel?.temperatureUnit.value?.unitTemperature,
           let l = viewModel?.dewPointLowerBound.value?.converted(to: tu),
           let u = viewModel?.dewPointUpperBound.value?.converted(to: tu) {
            let format = "TagSettings.Alerts.DewPoint.description".localized()
            dewPointAlertHeaderCell.descriptionLabel.text = String(format: format, l.value, u.value)
        } else {
            dewPointAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }

    private func updateUIMovementAlertDescription() {
        guard isViewLoaded else { return }
        if let isMovementAlertOn = viewModel?.isMovementAlertOn.value, isMovementAlertOn {
            movementAlertHeaderCell.descriptionLabel.text = "TagSettings.Alerts.Movement.description".localized()
        } else {
            movementAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }

    private func updateUIConnectionAlertDescription() {
        guard isViewLoaded else { return }
        if let isConnectionAlertOn = viewModel?.isConnectionAlertOn.value, isConnectionAlertOn {
            connectionAlertHeaderCell.descriptionLabel.text
                = "TagSettings.Alerts.Connection.description".localized()
        } else {
            connectionAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }
}
// swiftlint:enable file_length
