// swiftlint:disable file_length
import UIKit
import RangeSeekSlider

enum TagSettingsTableSection: Int {
    case image = 0
    case name = 1
    case connection = 2
    case alerts = 3
    case calibration = 4
    case moreInfo = 5

    static func showConnection(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.isConnectable.value ?? false
    }

    static func showAlerts(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.isConnectable.value ?? false
    }

    static func section(for sectionIndex: Int) -> TagSettingsTableSection {
        return TagSettingsTableSection(rawValue: sectionIndex) ?? .name
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

    @IBOutlet weak var absoluteHumidityAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var absoluteHumidityAlertControlsCell: TagSettingsAlertControlsCell!

    @IBOutlet weak var temperatureAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var temperatureAlertControlsCell: TagSettingsAlertControlsCell!

    @IBOutlet weak var relativeHumidityAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var relativeHumidityAlertControlsCell: TagSettingsAlertControlsCell!

    @IBOutlet weak var connectStatusLabel: UILabel!
    @IBOutlet weak var keepConnectionSwitch: UISwitch!
    @IBOutlet weak var keepConnectionTitleLabel: UILabel!
    @IBOutlet weak var dataSourceTitleLabel: UILabel!
    @IBOutlet weak var dataSourceValueLabel: UILabel!
    @IBOutlet weak var humidityLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var macValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var txPowerValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var mcValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var msnValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var msnCell: UITableViewCell!
    @IBOutlet weak var mcCell: UITableViewCell!
    @IBOutlet weak var txPowerCell: UITableViewCell!
    @IBOutlet weak var uuidCell: UITableViewCell!
    @IBOutlet weak var macAddressCell: UITableViewCell!
    @IBOutlet weak var tagNameCell: UITableViewCell!
    @IBOutlet weak var calibrationHumidityCell: UITableViewCell!
    @IBOutlet weak var uuidValueLabel: UILabel!
    @IBOutlet weak var accelerationXValueLabel: UILabel!
    @IBOutlet weak var accelerationYValueLabel: UILabel!
    @IBOutlet weak var accelerationZValueLabel: UILabel!
    @IBOutlet weak var voltageValueLabel: UILabel!
    @IBOutlet weak var macAddressValueLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tagNameTextField: UITextField!
    @IBOutlet weak var dataFormatValueLabel: UILabel!
    @IBOutlet weak var mcValueLabel: UILabel!
    @IBOutlet weak var msnValueLabel: UILabel!
    @IBOutlet weak var txPowerValueLabel: UILabel!
    @IBOutlet weak var backgroundImageLabel: UILabel!
    @IBOutlet weak var tagNameTitleLabel: UILabel!
    @IBOutlet weak var humidityTitleLabel: UILabel!
    @IBOutlet weak var uuidTitleLabel: UILabel!
    @IBOutlet weak var macAddressTitleLabel: UILabel!
    @IBOutlet weak var dataFormatTitleLabel: UILabel!
    @IBOutlet weak var batteryVoltageTitleLabel: UILabel!
    @IBOutlet weak var accelerationXTitleLabel: UILabel!
    @IBOutlet weak var accelerationYTitleLabel: UILabel!
    @IBOutlet weak var accelerationZTitleLabel: UILabel!
    @IBOutlet weak var txPowerTitleLabel: UILabel!
    @IBOutlet weak var mcTitleLabel: UILabel!
    @IBOutlet weak var msnTitleLabel: UILabel!
    @IBOutlet weak var removeThisRuuviTagButton: UIButton!

    var viewModel: TagSettingsViewModel? {
        didSet {
            bindViewModel()
        }
    }

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

    func localize() {
        navigationItem.title = "TagSettings.navigationItem.title".localized()
        backgroundImageLabel.text = "TagSettings.backgroundImageLabel.text".localized()
        tagNameTitleLabel.text = "TagSettings.tagNameTitleLabel.text".localized()
        humidityTitleLabel.text = "TagSettings.humidityTitleLabel.text".localized()
        uuidTitleLabel.text = "TagSettings.uuidTitleLabel.text".localized()
        macAddressTitleLabel.text = "TagSettings.macAddressTitleLabel.text".localized()
        dataFormatTitleLabel.text = "TagSettings.dataFormatTitleLabel.text".localized()
        batteryVoltageTitleLabel.text = "TagSettings.batteryVoltageTitleLabel.text".localized()
        accelerationXTitleLabel.text = "TagSettings.accelerationXTitleLabel.text".localized()
        accelerationYTitleLabel.text = "TagSettings.accelerationYTitleLabel.text".localized()
        accelerationZTitleLabel.text = "TagSettings.accelerationZTitleLabel.text".localized()
        txPowerTitleLabel.text = "TagSettings.txPowerTitleLabel.text".localized()
        mcTitleLabel.text = "TagSettings.mcTitleLabel.text".localized()
        msnTitleLabel.text = "TagSettings.msnTitleLabel.text".localized()
        dataSourceTitleLabel.text = "TagSettings.dataSourceTitleLabel.text".localized()
        removeThisRuuviTagButton.setTitle("TagSettings.removeThisRuuviTagButton.text".localized(), for: .normal)

        updateUITemperatureAlertDescription()
        keepConnectionTitleLabel.text = "TagSettings.KeepConnection.title".localized()
        relativeHumidityAlertHeaderCell.titleLabel.text
            = "TagSettings.RelativeAirHumidityAlert.title".localized()
            + " " + "%"
        absoluteHumidityAlertHeaderCell.titleLabel.text
            = "TagSettings.AbsoluteAirHumidityAlert.title".localized()
            + " " + "g/m³".localized()
        pressureAlertHeaderCell.titleLabel.text
            = "TagSettings.PressureAlert.title".localized()
            + " " + "hPa".localized()
        connectionAlertHeaderCell.titleLabel.text = "TagSettings.ConnectionAlert.title".localized()
        movementAlertHeaderCell.titleLabel.text = "TagSettings.MovementAlert.title".localized()

        let alertPlaceholder = "TagSettings.Alert.CustomDescription.placeholder".localized()
        temperatureAlertControlsCell.textField.placeholder = alertPlaceholder
        relativeHumidityAlertControlsCell.textField.placeholder = alertPlaceholder
        absoluteHumidityAlertControlsCell.textField.placeholder = alertPlaceholder
        dewPointAlertControlsCell.textField.placeholder = alertPlaceholder
        pressureAlertControlsCell.textField.placeholder = alertPlaceholder
        connectionAlertDescriptionCell.textField.placeholder = alertPlaceholder
        movementAlertDescriptionCell.textField.placeholder = alertPlaceholder

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
        if !keepConnectionSwitch.isOn {
            viewModel?.isTemperatureAlertOn.value = false
            viewModel?.isRelativeHumidityAlertOn.value = false
            viewModel?.isAbsoluteHumidityAlertOn.value = false
            viewModel?.isDewPointAlertOn.value = false
            viewModel?.isPressureAlertOn.value = false
            viewModel?.isMovementAlertOn.value = false
        }
    }
}

// MARK: - UITableViewDelegate
extension TagSettingsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell {
            case tagNameCell:
                tagNameTextField.becomeFirstResponder()
            case calibrationHumidityCell:
                output.viewDidAskToCalibrateHumidity()
            case macAddressCell:
                output.viewDidTapOnMacAddress()
            case uuidCell:
                output.viewDidTapOnUUID()
            case txPowerCell:
                output.viewDidTapOnTxPower()
            case mcCell:
                output.viewDidTapOnMovementCounter()
            case msnCell:
                output.viewDidTapOnMeasurementSequenceNumber()
            default:
                break
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = TagSettingsTableSection.section(for: section)
        switch section {
        case .name:
            return "TagSettings.SectionHeader.Name.title".localized()
        case .calibration:
            return "TagSettings.SectionHeader.Calibration.title".localized()
        case .connection:
            return TagSettingsTableSection.showConnection(for: viewModel)
                ? "TagSettings.SectionHeader.Connection.title".localized() : nil
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell {
            case calibrationHumidityCell:
                output.viewDidTapOnHumidityAccessoryButton()
            default:
                break
            }
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
            let isPN = viewModel?.isPushNotificationsEnabled.value ?? false
            let isCo = viewModel?.isConnected.value ?? false
            header.disabledView.isHidden = isPN && isCo
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
        default:
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if viewModel?.isConnectable.value ?? false {
            let headerHeight: CGFloat = 66
            let controlsHeight: CGFloat = 148
            let descriptionHeight: CGFloat = 60
            let hu = viewModel?.humidityUnit.value
            switch cell {
            case temperatureAlertHeaderCell:
                return headerHeight
            case temperatureAlertControlsCell:
                return (viewModel?.isTemperatureAlertOn.value ?? false) ? controlsHeight : 0
            case relativeHumidityAlertHeaderCell:
                return (hu == .percent) ? headerHeight : 0
            case relativeHumidityAlertControlsCell:
                return ((hu == .percent) && (viewModel?.isRelativeHumidityAlertOn.value ?? false)) ? controlsHeight : 0
            case absoluteHumidityAlertHeaderCell:
                return (hu == .gm3) ? headerHeight : 0
            case absoluteHumidityAlertControlsCell:
                return ((hu == .gm3) && (viewModel?.isAbsoluteHumidityAlertOn.value ?? false)) ? controlsHeight : 0
            case dewPointAlertHeaderCell:
                return (hu == .dew) ? headerHeight : 0
            case dewPointAlertControlsCell:
                return ((hu == .dew) && (viewModel?.isDewPointAlertOn.value ?? false)) ? controlsHeight : 0
            case pressureAlertHeaderCell:
                return headerHeight
            case pressureAlertControlsCell:
                return (viewModel?.isPressureAlertOn.value ?? false) ? controlsHeight : 0
            case connectionAlertHeaderCell:
                return headerHeight
            case connectionAlertDescriptionCell:
                return (viewModel?.isConnectionAlertOn.value ?? false) ? descriptionHeight : 0
            case movementAlertHeaderCell:
                return headerHeight
            case movementAlertDescriptionCell:
                return (viewModel?.isMovementAlertOn.value ?? false) ? descriptionHeight : 0
            default:
                return 44
            }
        } else {
            switch cell {
            case temperatureAlertHeaderCell,
                 temperatureAlertControlsCell,
                 relativeHumidityAlertHeaderCell,
                 relativeHumidityAlertControlsCell,
                 absoluteHumidityAlertHeaderCell,
                 absoluteHumidityAlertControlsCell,
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
        case relativeHumidityAlertHeaderCell:
            viewModel?.isRelativeHumidityAlertOn.value = isOn
        case absoluteHumidityAlertHeaderCell:
            viewModel?.isAbsoluteHumidityAlertOn.value = isOn
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
        case relativeHumidityAlertControlsCell:
            viewModel?.relativeHumidityAlertDescription.value = description
        case absoluteHumidityAlertControlsCell:
            viewModel?.absoluteHumidityAlertDescription.value = description
        case dewPointAlertControlsCell:
            viewModel?.dewPointAlertDescription.value = description
        case pressureAlertControlsCell:
            viewModel?.pressureAlertDescription.value = description
        default:
            break
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func tagSettingsAlertControls(cell: TagSettingsAlertControlsCell, didSlideTo minValue: CGFloat, maxValue: CGFloat) {
        switch cell {
        case temperatureAlertControlsCell:
            if let tu = viewModel?.temperatureUnit.value {
                switch tu {
                case .celsius:
                    viewModel?.celsiusLowerBound.value = Double(minValue)
                    viewModel?.celsiusUpperBound.value = Double(maxValue)
                case .fahrenheit:
                    viewModel?.celsiusLowerBound.value = Double(minValue).celsiusFromFahrenheit
                    viewModel?.celsiusUpperBound.value = Double(maxValue).celsiusFromFahrenheit
                case .kelvin:
                    viewModel?.celsiusLowerBound.value = Double(minValue).celsiusFromKelvin
                    viewModel?.celsiusUpperBound.value = Double(maxValue).celsiusFromKelvin
                }
            }
        case relativeHumidityAlertControlsCell:
            viewModel?.relativeHumidityLowerBound.value = Double(minValue)
            viewModel?.relativeHumidityUpperBound.value = Double(maxValue)
        case absoluteHumidityAlertControlsCell:
            viewModel?.absoluteHumidityLowerBound.value = Double(minValue)
            viewModel?.absoluteHumidityUpperBound.value = Double(maxValue)
        case dewPointAlertControlsCell:
            if let tu = viewModel?.temperatureUnit.value {
                switch tu {
                case .celsius:
                    viewModel?.dewPointCelsiusLowerBound.value = Double(minValue)
                    viewModel?.dewPointCelsiusUpperBound.value = Double(maxValue)
                case .fahrenheit:
                    viewModel?.dewPointCelsiusLowerBound.value = Double(minValue).celsiusFromFahrenheit
                    viewModel?.dewPointCelsiusUpperBound.value = Double(maxValue).celsiusFromFahrenheit
                case .kelvin:
                    viewModel?.dewPointCelsiusLowerBound.value = Double(minValue).celsiusFromKelvin
                    viewModel?.dewPointCelsiusUpperBound.value = Double(maxValue).celsiusFromKelvin
                }
            }
        case pressureAlertControlsCell:
            viewModel?.pressureLowerBound.value = Double(minValue)
            viewModel?.pressureUpperBound.value = Double(maxValue)
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
        relativeHumidityAlertHeaderCell.delegate = self
        relativeHumidityAlertControlsCell.delegate = self
        absoluteHumidityAlertHeaderCell.delegate = self
        absoluteHumidityAlertControlsCell.delegate = self
        dewPointAlertHeaderCell.delegate = self
        dewPointAlertControlsCell.delegate = self
        pressureAlertHeaderCell.delegate = self
        pressureAlertControlsCell.delegate = self
        connectionAlertHeaderCell.delegate = self
        connectionAlertDescriptionCell.delegate = self
        movementAlertHeaderCell.delegate = self
        movementAlertDescriptionCell.delegate = self
        configureMinMaxForSliders()
    }

    private func configureMinMaxForSliders() {
        let tu = viewModel?.temperatureUnit.value ?? .celsius
        switch tu {
        case .celsius:
            temperatureAlertControlsCell.slider.minValue = -40
            temperatureAlertControlsCell.slider.maxValue = 85
        case .fahrenheit:
            temperatureAlertControlsCell.slider.minValue = -40
            temperatureAlertControlsCell.slider.maxValue = 185
        case .kelvin:
            temperatureAlertControlsCell.slider.minValue = 233
            temperatureAlertControlsCell.slider.maxValue = 358
        }

        relativeHumidityAlertControlsCell.slider.minValue = 0
        relativeHumidityAlertControlsCell.slider.maxValue = 100

        absoluteHumidityAlertControlsCell.slider.minValue = 0
        absoluteHumidityAlertControlsCell.slider.maxValue = 40

        switch tu {
        case .celsius:
            dewPointAlertControlsCell.slider.minValue = -40
            dewPointAlertControlsCell.slider.maxValue = 85
        case .fahrenheit:
            dewPointAlertControlsCell.slider.minValue = -40
            dewPointAlertControlsCell.slider.maxValue = 185
        case .kelvin:
            dewPointAlertControlsCell.slider.minValue = 233
            dewPointAlertControlsCell.slider.maxValue = 358
        }

        pressureAlertControlsCell.slider.minValue = 300
        pressureAlertControlsCell.slider.maxValue = 1100
    }
}

// MARK: - Bindings
extension TagSettingsTableViewController {
    private func bindViewModels() {
        bindViewModel()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func bindViewModel() {
        bindHumidity()
        bindTemperatureAlertCells()
        bindRelativeHumidityCells()
        bindAbsoluteHumidityCells()
        bindDewPointAlertCells()
        bindPressureAlertCells()
        bindConnectionAlertCells()
        bindMovementAlertCell()
        if isViewLoaded, let viewModel = viewModel {

            dataSourceValueLabel.bind(viewModel.isConnected) { (label, isConnected) in
                if isConnected == true {
                    label.text = "TagSettings.DataSource.Heartbeat.title".localized()
                } else {
                    label.text = "TagSettings.DataSource.Advertisement.title".localized()
                }
            }
            dataSourceValueLabel.bind(viewModel.isNetworkConnected) { (label, isNetworkConnected) in
                if isNetworkConnected == true {
                    label.text = "TagSettings.DataSource.Network.title".localized()
                }
            }
            tableView.bind(viewModel.version) { (tableView, _) in
                tableView.reloadData()
            }

            tableView.bind(viewModel.humidityUnit) { tableView, _ in
                tableView.reloadData()
            }

            backgroundImageView.bind(viewModel.background) { $0.image = $1 }
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

            mcValueLabel.bind(viewModel.movementCounter) { (label, mc) in
                if let mc = mc {
                    label.text = "\(mc)"
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

            tableView.bind(viewModel.isConnectable) { (tableView, _) in
                tableView.reloadData()
            }

            tableView.bind(viewModel.isConnected) { (tableView, _) in
                tableView.reloadData()
            }

            tableView.bind(viewModel.isPushNotificationsEnabled) { (tableView, _) in
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
        }
    }

    private func bindHumidity() {
       if isViewLoaded, let viewModel = viewModel {
           let humidity = viewModel.relativeHumidity
           let humidityOffset = viewModel.humidityOffset
           let humidityCell = calibrationHumidityCell
           let humidityTrailing = humidityLabelTrailing

           let humidityBlock: ((UILabel, Double?) -> Void) = {
            [weak humidity,
            weak humidityOffset,
            weak humidityCell,
            weak humidityTrailing] label, _ in
               if let humidity = humidity?.value, let humidityOffset = humidityOffset?.value {
                   if humidityOffset > 0 {
                       let shownHumidity = humidity + humidityOffset
                       if shownHumidity > 100.0 {
                           label.text = "\(String.localizedStringWithFormat("%.2f", humidity))"
                            + " → " + "\(String.localizedStringWithFormat("%.2f", 100.0))"
                           humidityCell?.accessoryType = .detailButton
                           humidityTrailing?.constant = 0
                       } else {
                           label.text = "\(String.localizedStringWithFormat("%.2f", humidity))"
                            + " → " + "\(String.localizedStringWithFormat("%.2f", shownHumidity))"
                           humidityCell?.accessoryType = .none
                           humidityTrailing?.constant = 16.0
                       }
                   } else {
                       label.text = nil
                       humidityCell?.accessoryType = .none
                       humidityTrailing?.constant = 16.0
                   }
               } else {
                   label.text = nil
               }
           }

           humidityLabel.bind(viewModel.relativeHumidity, block: humidityBlock)
           humidityLabel.bind(viewModel.humidityOffset, block: humidityBlock)
       }
    }

    // swiftlint:disable:next function_body_length
    private func bindTemperatureAlertCells() {
        if isViewLoaded, let viewModel = viewModel {
            temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isTemperatureAlertOn) { (view, isOn) in
                view.isOn = isOn.bound
            }
            temperatureAlertControlsCell.slider.bind(viewModel.isTemperatureAlertOn) { (slider, isOn) in
                slider.isEnabled = isOn.bound
            }

            temperatureAlertControlsCell.slider.bind(viewModel.celsiusLowerBound) { [weak self] (_, _) in
                self?.updateUICelsiusLowerBound()
                self?.updateUITemperatureAlertDescription()
            }
            temperatureAlertControlsCell.slider.bind(viewModel.celsiusUpperBound) { [weak self] (_, _) in
                self?.updateUICelsiusUpperBound()
                self?.updateUITemperatureAlertDescription()
            }

            temperatureAlertHeaderCell.titleLabel.bind(viewModel.temperatureUnit) { (label, temperatureUnit) in
                if let tu = temperatureUnit {
                    let title = "TagSettings.temperatureAlertTitleLabel.text"
                    label.text = title.localized() + " " + tu.symbol
                } else {
                    label.text = "N/A".localized()
                }
            }

            temperatureAlertControlsCell.slider.bind(viewModel.temperatureUnit) { (slider, temperatureUnit) in
                if let tu = temperatureUnit {
                    switch tu {
                    case .celsius:
                        slider.minValue = -40
                        slider.maxValue = 85
                    case .fahrenheit:
                        slider.minValue = -40
                        slider.maxValue = 185
                    case .kelvin:
                        slider.minValue = 233
                        slider.maxValue = 358
                    }
                }
            }

            temperatureAlertHeaderCell.descriptionLabel.bind(viewModel.isTemperatureAlertOn) { [weak self] (_, _) in
                self?.updateUITemperatureAlertDescription()
            }

            let isPNEnabled = viewModel.isPushNotificationsEnabled
            let isTemperatureAlertOn = viewModel.isTemperatureAlertOn
            let isConnected = viewModel.isConnected

            temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isConnected) {
                [weak isPNEnabled] (view, isConnected) in
                let isPN = isPNEnabled?.value ?? false
                let isEnabled = isPN && isConnected.bound
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
                [weak isConnected] view, isPushNotificationsEnabled in
                let isPN = isPushNotificationsEnabled ?? false
                let isCo = isConnected?.value ?? false
                let isEnabled = isPN && isCo
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            temperatureAlertControlsCell.slider.bind(viewModel.isConnected) {
                [weak isTemperatureAlertOn, weak isPNEnabled] (slider, isConnected) in
                let isPN = isPNEnabled?.value ?? false
                let isOn = isTemperatureAlertOn?.value ?? false
                slider.isEnabled = isConnected.bound && isOn && isPN
            }

            temperatureAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {
                [weak isTemperatureAlertOn, weak isConnected] (slider, isPushNotificationsEnabled) in
                let isOn = isTemperatureAlertOn?.value ?? false
                let isCo = isConnected?.value ?? false
                slider.isEnabled = isPushNotificationsEnabled.bound && isOn && isCo
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
    }

    private func bindConnectionAlertCells() {
        if isViewLoaded, let viewModel = viewModel {
            connectionAlertHeaderCell.isOnSwitch.bind(viewModel.isConnectionAlertOn) { (view, isOn) in
                view.isOn = isOn.bound
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
    }

    private func bindMovementAlertCell() {
        if isViewLoaded, let viewModel = viewModel {
            movementAlertHeaderCell.isOnSwitch.bind(viewModel.isMovementAlertOn) { (view, isOn) in
                view.isOn = isOn.bound
            }

            movementAlertHeaderCell.descriptionLabel.bind(viewModel.isMovementAlertOn) { [weak self] (_, _) in
                self?.updateUIMovementAlertDescription()
            }

            let isPNEnabled = viewModel.isPushNotificationsEnabled
            let isConnected = viewModel.isConnected

            movementAlertHeaderCell.isOnSwitch.bind(viewModel.isConnected) { [weak isPNEnabled] (view, isConnected) in
                let isPN = isPNEnabled?.value ?? false
                let isEnabled = isPN && isConnected.bound
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            movementAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
                [weak isConnected] view, isPushNotificationsEnabled in
                let isPN = isPushNotificationsEnabled ?? false
                let isCo = isConnected?.value ?? false
                let isEnabled = isPN && isCo
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
    }

    // swiftlint:disable:next function_body_length
    private func bindPressureAlertCells() {
       if isViewLoaded, let viewModel = viewModel {
           pressureAlertHeaderCell.isOnSwitch.bind(viewModel.isPressureAlertOn) { (view, isOn) in
               view.isOn = isOn.bound
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
           pressureAlertHeaderCell.descriptionLabel.bind(viewModel.isPressureAlertOn) { [weak self] (_, _) in
               self?.updateUIPressureAlertDescription()
           }

           let isPNEnabled = viewModel.isPushNotificationsEnabled
           let isPressureAlertOn = viewModel.isPressureAlertOn
           let isConnected = viewModel.isConnected

           pressureAlertHeaderCell.isOnSwitch.bind(viewModel.isConnected) { [weak isPNEnabled] (view, isConnected) in
               let isPN = isPNEnabled?.value ?? false
               let isEnabled = isPN && isConnected.bound
               view.isEnabled = isEnabled
               view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
           }

           pressureAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
               [weak isConnected] view, isPushNotificationsEnabled in
               let isPN = isPushNotificationsEnabled ?? false
               let isCo = isConnected?.value ?? false
               let isEnabled = isPN && isCo
               view.isEnabled = isEnabled
               view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
           }

           pressureAlertControlsCell.slider.bind(viewModel.isConnected) {
               [weak isPressureAlertOn, weak isPNEnabled] (slider, isConnected) in
               let isPN = isPNEnabled?.value ?? false
               let isOn = isPressureAlertOn?.value ?? false
               slider.isEnabled = isConnected.bound && isOn && isPN
           }

           pressureAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {
               [weak isPressureAlertOn, weak isConnected] (slider, isPushNotificationsEnabled) in
               let isOn = isPressureAlertOn?.value ?? false
               let isCo = isConnected?.value ?? false
               slider.isEnabled = isPushNotificationsEnabled.bound && isOn && isCo
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
    }

    // swiftlint:disable:next function_body_length
    private func bindRelativeHumidityCells() {
        if isViewLoaded, let viewModel = viewModel {
            relativeHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isRelativeHumidityAlertOn) { (view, isOn) in
                view.isOn = isOn.bound
            }

            relativeHumidityAlertControlsCell.slider.bind(viewModel.isRelativeHumidityAlertOn) { (slider, isOn) in
                slider.isEnabled = isOn.bound
            }

            relativeHumidityAlertControlsCell.slider.bind(viewModel.relativeHumidityLowerBound) { [weak self] (_, _) in
                self?.updateUIRelativeHumidityLowerBound()
                self?.updateUIRelativeHumidityAlertDescription()
            }

            relativeHumidityAlertControlsCell.slider.bind(viewModel.relativeHumidityUpperBound) { [weak self] (_, _) in
                self?.updateUIRelativeHumidityUpperBound()
                self?.updateUIRelativeHumidityAlertDescription()
            }
            relativeHumidityAlertHeaderCell.descriptionLabel.bind(viewModel.isRelativeHumidityAlertOn) {
                [weak self] (_, _) in
                self?.updateUIRelativeHumidityAlertDescription()
            }

            let isPNEnabled = viewModel.isPushNotificationsEnabled
            let isRelativeHumidityAlertOn = viewModel.isRelativeHumidityAlertOn
            let isConnected = viewModel.isConnected

            relativeHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isConnected) {
                [weak isPNEnabled] (view, isConnected) in
                let isPN = isPNEnabled?.value ?? false
                let isEnabled = isPN && isConnected.bound
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            relativeHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
                [weak isConnected] view, isPushNotificationsEnabled in
                let isPN = isPushNotificationsEnabled ?? false
                let isCo = isConnected?.value ?? false
                let isEnabled = isPN && isCo
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            relativeHumidityAlertControlsCell.slider.bind(viewModel.isConnected) {
                [weak isRelativeHumidityAlertOn, weak isPNEnabled] (slider, isConnected) in
                let isPN = isPNEnabled?.value ?? false
                let isOn = isRelativeHumidityAlertOn?.value ?? false
                slider.isEnabled = isConnected.bound && isOn && isPN
            }

            relativeHumidityAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {
                [weak isRelativeHumidityAlertOn, weak isConnected] (slider, isPushNotificationsEnabled) in
                let isOn = isRelativeHumidityAlertOn?.value ?? false
                let isCo = isConnected?.value ?? false
                slider.isEnabled = isPushNotificationsEnabled.bound && isOn && isCo
            }

            relativeHumidityAlertControlsCell.textField.bind(viewModel.relativeHumidityAlertDescription) {
                (textField, relativeHumidityAlertDescription) in
                textField.text = relativeHumidityAlertDescription
            }

            tableView.bind(viewModel.isRelativeHumidityAlertOn) { tableView, _ in
                if tableView.window != nil {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindAbsoluteHumidityCells() {
        if isViewLoaded, let viewModel = viewModel {
            absoluteHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isAbsoluteHumidityAlertOn) { (view, isOn) in
                view.isOn = isOn.bound
            }

            absoluteHumidityAlertControlsCell.slider.bind(viewModel.isAbsoluteHumidityAlertOn) { (slider, isOn) in
                slider.isEnabled = isOn.bound
            }

            absoluteHumidityAlertControlsCell.slider.bind(viewModel.absoluteHumidityLowerBound) { [weak self] (_, _) in
                self?.updateUIAbsoluteHumidityLowerBound()
                self?.updateUIAbsoluteHumidityAlertDescription()
            }

            absoluteHumidityAlertControlsCell.slider.bind(viewModel.absoluteHumidityUpperBound) { [weak self] (_, _) in
                self?.updateUIAbsoluteHumidityUpperBound()
                self?.updateUIAbsoluteHumidityAlertDescription()
            }
            absoluteHumidityAlertHeaderCell.descriptionLabel.bind(viewModel.isAbsoluteHumidityAlertOn) {
                [weak self] (_, _) in
                self?.updateUIAbsoluteHumidityAlertDescription()
            }

            let isPNEnabled = viewModel.isPushNotificationsEnabled
            let isAbsoluteHumidityAlertOn = viewModel.isAbsoluteHumidityAlertOn
            let isConnected = viewModel.isConnected

            absoluteHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isConnected) {
                [weak isPNEnabled] (view, isConnected) in
                let isPN = isPNEnabled?.value ?? false
                let isEnabled = isPN && isConnected.bound
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            absoluteHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
                [weak isConnected] view, isPushNotificationsEnabled in
                let isPN = isPushNotificationsEnabled ?? false
                let isCo = isConnected?.value ?? false
                let isEnabled = isPN && isCo
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            absoluteHumidityAlertControlsCell.slider.bind(viewModel.isConnected) {
                [weak isAbsoluteHumidityAlertOn, weak isPNEnabled] (slider, isConnected) in
                let isPN = isPNEnabled?.value ?? false
                let isOn = isAbsoluteHumidityAlertOn?.value ?? false
                slider.isEnabled = isConnected.bound && isOn && isPN
            }

            absoluteHumidityAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {
                [weak isAbsoluteHumidityAlertOn, weak isConnected] (slider, isPushNotificationsEnabled) in
                let isOn = isAbsoluteHumidityAlertOn?.value ?? false
                let isCo = isConnected?.value ?? false
                slider.isEnabled = isPushNotificationsEnabled.bound && isOn && isCo
            }

            absoluteHumidityAlertControlsCell.textField.bind(viewModel.absoluteHumidityAlertDescription) {
                (textField, absoluteHumidityAlertDescription) in
                textField.text = absoluteHumidityAlertDescription
            }

            tableView.bind(viewModel.isAbsoluteHumidityAlertOn) { tableView, _ in
                if tableView.window != nil {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindDewPointAlertCells() {
        if isViewLoaded, let viewModel = viewModel {
            dewPointAlertHeaderCell.isOnSwitch.bind(viewModel.isDewPointAlertOn) { (view, isOn) in
                view.isOn = isOn.bound
            }

            dewPointAlertControlsCell.slider.bind(viewModel.isDewPointAlertOn) { (slider, isOn) in
                slider.isEnabled = isOn.bound
            }

            dewPointAlertControlsCell.slider.bind(viewModel.dewPointCelsiusLowerBound) { [weak self] (_, _) in
                self?.updateUIDewPointCelsiusLowerBound()
                self?.updateUIDewPointAlertDescription()
            }

            dewPointAlertControlsCell.slider.bind(viewModel.dewPointCelsiusUpperBound) { [weak self] (_, _) in
                self?.updateUIDewPointCelsiusUpperBound()
                self?.updateUIDewPointAlertDescription()
            }

            dewPointAlertHeaderCell.titleLabel.bind(viewModel.temperatureUnit) { (label, temperatureUnit) in
                if let tu = temperatureUnit {
                    let title = "TagSettings.dewPointAlertTitleLabel.text"
                    label.text = title.localized() + " " + tu.symbol
                } else {
                    label.text = "N/A".localized()
                }
            }

            dewPointAlertControlsCell.slider.bind(viewModel.temperatureUnit) { (slider, temperatureUnit) in
                if let tu = temperatureUnit {
                    switch tu {
                    case .celsius:
                        slider.minValue = -40
                        slider.maxValue = 85
                    case .fahrenheit:
                        slider.minValue = -40
                        slider.maxValue = 185
                    case .kelvin:
                        slider.minValue = 233
                        slider.maxValue = 358
                    }
                }
            }

            dewPointAlertHeaderCell.descriptionLabel.bind(viewModel.isDewPointAlertOn) { [weak self] (_, _) in
                self?.updateUIDewPointAlertDescription()
            }

            let isPNEnabled = viewModel.isPushNotificationsEnabled
            let isDewPointAlertOn = viewModel.isDewPointAlertOn
            let isConnected = viewModel.isConnected

            dewPointAlertHeaderCell.isOnSwitch.bind(viewModel.isConnected) { [weak isPNEnabled] (view, isConnected) in
                let isPN = isPNEnabled?.value ?? false
                let isEnabled = isPN && isConnected.bound
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            dewPointAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
                [weak isConnected] view, isPushNotificationsEnabled in
                let isPN = isPushNotificationsEnabled ?? false
                let isCo = isConnected?.value ?? false
                let isEnabled = isPN && isCo
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            dewPointAlertControlsCell.slider.bind(viewModel.isConnected) {
                [weak isDewPointAlertOn, weak isPNEnabled] (slider, isConnected) in
                let isPN = isPNEnabled?.value ?? false
                let isOn = isDewPointAlertOn?.value ?? false
                slider.isEnabled = isConnected.bound && isOn && isPN
            }

            dewPointAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {
                [weak isDewPointAlertOn, weak isConnected] (slider, isPushNotificationsEnabled) in
                let isOn = isDewPointAlertOn?.value ?? false
                let isCo = isConnected?.value ?? false
                slider.isEnabled = isPushNotificationsEnabled.bound && isOn && isCo
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
        updateUICelsiusLowerBound()
        updateUICelsiusUpperBound()

        updateUIRelativeHumidityAlertDescription()
        updateUIRelativeHumidityLowerBound()
        updateUIRelativeHumidityUpperBound()

        updateUIAbsoluteHumidityAlertDescription()
        updateUIAbsoluteHumidityLowerBound()
        updateUIAbsoluteHumidityUpperBound()

        updateUIDewPointAlertDescription()
        updateUIDewPointCelsiusLowerBound()
        updateUIDewPointCelsiusUpperBound()
    }

    private func updateUIPressureLowerBound() {
        if isViewLoaded {
            if let lower = viewModel?.pressureLowerBound.value {
                pressureAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
            } else {
                pressureAlertControlsCell.slider.selectedMinValue = 300
            }
        }
    }

    private func updateUIPressureUpperBound() {
        if isViewLoaded {
            if let upper = viewModel?.pressureUpperBound.value {
                pressureAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
            } else {
                pressureAlertControlsCell.slider.selectedMaxValue = 1100
            }
        }
    }

    private func updateUIAbsoluteHumidityLowerBound() {
        if isViewLoaded {
            if let lower = viewModel?.absoluteHumidityLowerBound.value {
                absoluteHumidityAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
            } else {
                absoluteHumidityAlertControlsCell.slider.selectedMinValue = 0
            }
        }
    }

    private func updateUIRelativeHumidityLowerBound() {
        if isViewLoaded {
            if let lower = viewModel?.relativeHumidityLowerBound.value {
                relativeHumidityAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
            } else {
                relativeHumidityAlertControlsCell.slider.selectedMinValue = 0
            }
        }
    }

    private func updateUIAbsoluteHumidityUpperBound() {
        if isViewLoaded {
            if let upper = viewModel?.absoluteHumidityUpperBound.value {
                absoluteHumidityAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
            } else {
                absoluteHumidityAlertControlsCell.slider.selectedMaxValue = 40
            }
        }
    }

    private func updateUIRelativeHumidityUpperBound() {
        if isViewLoaded {
            if let upper = viewModel?.relativeHumidityUpperBound.value {
                relativeHumidityAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
            } else {
                relativeHumidityAlertControlsCell.slider.selectedMaxValue = 100
            }
        }
    }

    private func updateUIAbsoluteHumidityAlertDescription() {
        if isViewLoaded {
            if let isAbsoluteHumidityAlertOn = viewModel?.isAbsoluteHumidityAlertOn.value, isAbsoluteHumidityAlertOn {
                if let l = viewModel?.absoluteHumidityLowerBound.value,
                    let u = viewModel?.absoluteHumidityUpperBound.value {
                    let format = "TagSettings.Alerts.AbsoluteHumidity.description".localized()
                    absoluteHumidityAlertHeaderCell.descriptionLabel.text = String(format: format, l, u)
                } else {
                    absoluteHumidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                absoluteHumidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUIMovementAlertDescription() {
        if isViewLoaded {
            if let isMovementAlertOn = viewModel?.isMovementAlertOn.value, isMovementAlertOn {
                movementAlertHeaderCell.descriptionLabel.text = "TagSettings.Alerts.Movement.description".localized()
            } else {
                movementAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUIConnectionAlertDescription() {
        if isViewLoaded {
            if let isConnectionAlertOn = viewModel?.isConnectionAlertOn.value, isConnectionAlertOn {
                connectionAlertHeaderCell.descriptionLabel.text
                    = "TagSettings.Alerts.Connection.description".localized()
            } else {
                connectionAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUIPressureAlertDescription() {
        if isViewLoaded {
            if let isPressureAlertOn = viewModel?.isPressureAlertOn.value,
                isPressureAlertOn {
                if let l = viewModel?.pressureLowerBound.value,
                    let u = viewModel?.pressureUpperBound.value {
                    let format = "TagSettings.Alerts.Pressure.description".localized()
                    pressureAlertHeaderCell.descriptionLabel.text = String(format: format, l, u)
                } else {
                    pressureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                pressureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUIRelativeHumidityAlertDescription() {
        if isViewLoaded {
            if let isRelativeHumidityAlertOn = viewModel?.isRelativeHumidityAlertOn.value,
                isRelativeHumidityAlertOn {
                if let l = viewModel?.relativeHumidityLowerBound.value,
                    let u = viewModel?.relativeHumidityUpperBound.value {
                    let format = "TagSettings.Alerts.RelativeHumidity.description".localized()
                    relativeHumidityAlertHeaderCell.descriptionLabel.text = String(format: format, l, u)
                } else {
                    relativeHumidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                relativeHumidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUIDewPointCelsiusLowerBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel?.temperatureUnit.value {
                if let lower = viewModel?.dewPointCelsiusLowerBound.value {
                    switch temperatureUnit {
                    case .celsius:
                        dewPointAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
                    case .fahrenheit:
                        dewPointAlertControlsCell.slider.selectedMinValue = CGFloat(lower.fahrenheit)
                    case .kelvin:
                        dewPointAlertControlsCell.slider.selectedMinValue = CGFloat(lower.kelvin)
                    }
                } else {
                    dewPointAlertControlsCell.slider.selectedMinValue = -40
                }
            } else {
                dewPointAlertControlsCell.slider.minValue = -40
                dewPointAlertControlsCell.slider.selectedMinValue = -40
            }
        }
    }

    private func updateUICelsiusLowerBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel?.temperatureUnit.value {
                if let lower = viewModel?.celsiusLowerBound.value {
                    switch temperatureUnit {
                    case .celsius:
                        temperatureAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
                    case .fahrenheit:
                        temperatureAlertControlsCell.slider.selectedMinValue = CGFloat(lower.fahrenheit)
                    case .kelvin:
                        temperatureAlertControlsCell.slider.selectedMinValue = CGFloat(lower.kelvin)
                    }
                } else {
                    temperatureAlertControlsCell.slider.selectedMinValue = -40
                }
            } else {
                temperatureAlertControlsCell.slider.minValue = -40
                temperatureAlertControlsCell.slider.selectedMinValue = -40
            }
        }
    }

    private func updateUIDewPointCelsiusUpperBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel?.temperatureUnit.value {
                if let upper = viewModel?.dewPointCelsiusUpperBound.value {
                    switch temperatureUnit {
                    case .celsius:
                        dewPointAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
                    case .fahrenheit:
                        dewPointAlertControlsCell.slider.selectedMaxValue = CGFloat(upper.fahrenheit)
                    case .kelvin:
                        dewPointAlertControlsCell.slider.selectedMaxValue = CGFloat(upper.kelvin)
                    }
                } else {
                    dewPointAlertControlsCell.slider.selectedMaxValue = 85
                }
            } else {
                dewPointAlertControlsCell.slider.maxValue = 85
                dewPointAlertControlsCell.slider.selectedMaxValue = 85
            }
        }
    }

    private func updateUICelsiusUpperBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel?.temperatureUnit.value {
                if let upper = viewModel?.celsiusUpperBound.value {
                    switch temperatureUnit {
                    case .celsius:
                        temperatureAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
                    case .fahrenheit:
                        temperatureAlertControlsCell.slider.selectedMaxValue = CGFloat(upper.fahrenheit)
                    case .kelvin:
                        temperatureAlertControlsCell.slider.selectedMaxValue = CGFloat(upper.kelvin)
                    }
                } else {
                    temperatureAlertControlsCell.slider.selectedMaxValue = 85
                }
            } else {
                temperatureAlertControlsCell.slider.maxValue = 85
                temperatureAlertControlsCell.slider.selectedMaxValue = 85
            }
        }
    }

    private func updateUIDewPointAlertDescription() {
        if isViewLoaded {
            if let isDewPointAlertOn = viewModel?.isDewPointAlertOn.value, isDewPointAlertOn {
                if let l = viewModel?.dewPointCelsiusLowerBound.value,
                    let u = viewModel?.dewPointCelsiusUpperBound.value,
                    let tu = viewModel?.temperatureUnit.value {
                    var la: Double
                    var ua: Double
                    switch tu {
                    case .celsius:
                        la = l
                        ua = u
                    case .fahrenheit:
                        la = l.fahrenheit
                        ua = u.fahrenheit
                    case .kelvin:
                        la = l.kelvin
                        ua = u.kelvin
                    }
                    let format = "TagSettings.Alerts.DewPoint.description".localized()
                    dewPointAlertHeaderCell.descriptionLabel.text = String(format: format, la, ua)
                } else {
                    dewPointAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                dewPointAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUITemperatureAlertDescription() {
        if isViewLoaded {
            if let isTemperatureAlertOn = viewModel?.isTemperatureAlertOn.value, isTemperatureAlertOn {
                if let l = viewModel?.celsiusLowerBound.value,
                    let u = viewModel?.celsiusUpperBound.value,
                    let tu = viewModel?.temperatureUnit.value {
                    var la: Double
                    var ua: Double
                    switch tu {
                    case .celsius:
                        la = l
                        ua = u
                    case .fahrenheit:
                        la = l.fahrenheit
                        ua = u.fahrenheit
                    case .kelvin:
                        la = l.kelvin
                        ua = u.kelvin
                    }
                    let format = "TagSettings.Alerts.Temperature.description".localized()
                    temperatureAlertHeaderCell.descriptionLabel.text = String(format: format, la, ua)
                } else {
                    temperatureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                temperatureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }
}
// swiftlint:enable file_length
