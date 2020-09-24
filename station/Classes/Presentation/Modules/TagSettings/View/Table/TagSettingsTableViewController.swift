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

    @IBOutlet weak var temperatureAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var temperatureAlertControlsCell: TagSettingsAlertControlsCell!

    @IBOutlet weak var humidityAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var humidityAlertControlsCell: TagSettingsAlertControlsCell!

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
        humidityAlertHeaderCell.titleLabel.text
            = "TagSettings.AirHumidityAlert.title".localized()
        pressureAlertHeaderCell.titleLabel.text
            = "TagSettings.PressureAlert.title".localized()
        connectionAlertHeaderCell.titleLabel.text = "TagSettings.ConnectionAlert.title".localized()
        movementAlertHeaderCell.titleLabel.text = "TagSettings.MovementAlert.title".localized()

        let alertPlaceholder = "TagSettings.Alert.CustomDescription.placeholder".localized()
        temperatureAlertControlsCell.textField.placeholder = alertPlaceholder
        humidityAlertControlsCell.textField.placeholder = alertPlaceholder
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
            viewModel?.isHumidityAlertOn.value = false
            viewModel?.isPressureAlertOn.value = false
            viewModel?.isMovementAlertOn.value = false
        }
    }
}

// MARK: - UITableViewDelegate
extension TagSettingsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
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
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        switch cell {
        case calibrationHumidityCell:
            output.viewDidTapOnHumidityAccessoryButton()
        default:
            break
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
        if viewModel?.isConnectable.value == true {
            let headerHeight: CGFloat = 66
            let controlsHeight: CGFloat = 148
            let descriptionHeight: CGFloat = 60
            switch cell {
            case temperatureAlertHeaderCell:
                return headerHeight
            case temperatureAlertControlsCell:
                return (viewModel?.isTemperatureAlertOn.value ?? false) ? controlsHeight : 0
            case humidityAlertHeaderCell:
                return headerHeight
            case humidityAlertControlsCell:
                return (viewModel?.isHumidityAlertOn.value ?? false) ? controlsHeight : 0
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
                 humidityAlertHeaderCell,
                 humidityAlertControlsCell,
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
                viewModel?.celsiusLowerBound.value = Temperature(Double(minValue), unit: tu.unitTemperature)
                viewModel?.celsiusUpperBound.value = Temperature(Double(maxValue), unit: tu.unitTemperature)
            }
        case humidityAlertControlsCell:
            if let hu = viewModel?.humidityUnit.value,
               let t = viewModel?.temperature.value {
                switch hu {
                case .gm3:
                    viewModel?.humidityLowerBound.value = Humidity(value: Double(minValue), unit: .absolute)
                    viewModel?.humidityUpperBound.value = Humidity(value: Double(maxValue), unit: .absolute)
                default:
                    viewModel?.humidityLowerBound.value = Humidity(value: Double(minValue / 100.0),
                                                                   unit: .relative(temperature: t))
                    viewModel?.humidityUpperBound.value = Humidity(value: Double(maxValue / 100.0),
                                                                   unit: .relative(temperature: t))
                }
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
        humidityAlertControlsCell.delegate = self
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
        temperatureAlertControlsCell.slider.minValue = CGFloat(tu.alertRange.lowerBound)
        temperatureAlertControlsCell.slider.maxValue = CGFloat(tu.alertRange.upperBound)

        let hu = viewModel?.humidityUnit.value ?? .percent
        humidityAlertControlsCell.slider.minValue = CGFloat(hu.alertRange.lowerBound)
        humidityAlertControlsCell.slider.maxValue = CGFloat(hu.alertRange.upperBound)

        let p = viewModel?.pressureUnit.value ?? .hectopascals
        pressureAlertControlsCell.slider.minValue = CGFloat(p.alertRange.lowerBound)
        pressureAlertControlsCell.slider.maxValue = CGFloat(p.alertRange.upperBound)
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
        bindHumidityAlertCells()
        bindPressureAlertCells()
        bindConnectionAlertCells()
        bindMovementAlertCell()
        guard isViewLoaded, let viewModel = viewModel  else { return }

        dataSourceValueLabel.bind(viewModel.isConnected) { (label, isConnected) in
            if let isConnected = isConnected, isConnected {
                label.text = "TagSettings.DataSource.Heartbeat.title".localized()
            } else {
                label.text = "TagSettings.DataSource.Advertisement.title".localized()
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

    private func bindHumidity() {
        guard isViewLoaded, let viewModel = viewModel else { return }
        let temperature = viewModel.temperature.value
        let humidity = viewModel.humidity.value
        let humidityOffset = viewModel.humidityOffset.value
        let humidityCell = calibrationHumidityCell
        let humidityTrailing = humidityLabelTrailing

        let humidityBlock: ((UILabel, Any?) -> Void) = {
            [weak humidityCell,
             weak humidityTrailing] label, _ in
            // TODO with use measurement service
            if let temperature = temperature,
               let humidityOffset = humidityOffset,
               let humidity = humidity?.converted(to: .relative(temperature: temperature)).value {
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
        humidityLabel.bind(viewModel.humidity, block: humidityBlock)
        humidityLabel.bind(viewModel.humidityOffset, block: humidityBlock)
    }

    // swiftlint:disable:next function_body_length
    private func bindTemperatureAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
        temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isTemperatureAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }
        temperatureAlertControlsCell.slider.bind(viewModel.isTemperatureAlertOn) { (slider, isOn) in
            slider.isEnabled = isOn.bound
        }

        temperatureAlertControlsCell.slider.bind(viewModel.celsiusLowerBound) { [weak self] (_, _) in
            self?.updateUITemperatureLowerBound()
            self?.updateUITemperatureAlertDescription()
        }
        temperatureAlertControlsCell.slider.bind(viewModel.celsiusUpperBound) { [weak self] (_, _) in
            self?.updateUITemperatureUpperBound()
            self?.updateUITemperatureAlertDescription()
        }

        temperatureAlertHeaderCell.titleLabel.bind(viewModel.temperatureUnit) { (label, temperatureUnit) in
            let title = "TagSettings.temperatureAlertTitleLabel.text"
            label.text = title.localized()
                + " "
                + (temperatureUnit?.symbol ?? "N/A".localized())
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

    private func bindConnectionAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
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

    private func bindMovementAlertCell() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
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

    // swiftlint:disable:next function_body_length
    private func bindPressureAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
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

        pressureAlertHeaderCell.titleLabel.bind(viewModel.pressureUnit) { (label, pressureUnit) in
            let title = "TagSettings.PressureAlert.title"
            label.text = title.localized()
                + " "
                + (pressureUnit?.symbol ?? "N/A".localized())
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

    // swiftlint:disable:next function_body_length
    private func bindHumidityAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }
        humidityAlertHeaderCell.isOnSwitch.bind(viewModel.isHumidityAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
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

        humidityAlertHeaderCell.titleLabel.bind(viewModel.humidityUnit) { (label, humidityUnit) in
            let title = "TagSettings.AirHumidityAlert.title"
            let symbol = humidityUnit == .dew ? HumidityUnit.percent.symbol : humidityUnit?.symbol
            label.text = title.localized()
                + " "
                + (symbol ?? "N/A".localized())
        }

        humidityAlertControlsCell.slider.bind(viewModel.humidityUnit) { (slider, humidityUnit) in
            if let hu = humidityUnit {
                slider.minValue = CGFloat(hu.alertRange.lowerBound)
                slider.maxValue = CGFloat(hu.alertRange.upperBound)
            }
        }

        humidityAlertHeaderCell.descriptionLabel.bind(viewModel.isHumidityAlertOn) {
            [weak self] (_, _) in
            self?.updateUIHumidityAlertDescription()
        }

        let isPNEnabled = viewModel.isPushNotificationsEnabled
        let isHumidityAlertOn = viewModel.isHumidityAlertOn
        let isConnected = viewModel.isConnected

        humidityAlertHeaderCell.isOnSwitch.bind(viewModel.isConnected) {
            [weak isPNEnabled] (view, isConnected) in
            let isPN = isPNEnabled?.value ?? false
            let isEnabled = isPN && isConnected.bound
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        humidityAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
            [weak isConnected] view, isPushNotificationsEnabled in
            let isPN = isPushNotificationsEnabled ?? false
            let isCo = isConnected?.value ?? false
            let isEnabled = isPN && isCo
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        humidityAlertControlsCell.slider.bind(viewModel.isConnected) {
            [weak isHumidityAlertOn, weak isPNEnabled] (slider, isConnected) in
            let isPN = isPNEnabled?.value ?? false
            let isOn = isHumidityAlertOn?.value ?? false
            slider.isEnabled = isConnected.bound && isOn && isPN
        }

        humidityAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {
            [weak isHumidityAlertOn, weak isConnected] (slider, isPushNotificationsEnabled) in
            let isOn = isHumidityAlertOn?.value ?? false
            let isCo = isConnected?.value ?? false
            slider.isEnabled = isPushNotificationsEnabled.bound && isOn && isCo
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
    }
    // MARK: - updateUITemperature

    private func updateUITemperatureLowerBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel?.temperatureUnit.value else {
            temperatureAlertControlsCell.slider.minValue = -40
            temperatureAlertControlsCell.slider.selectedMinValue = -40
            return
        }
        if let lower = viewModel?.celsiusLowerBound.value?.converted(to: temperatureUnit.unitTemperature) {
            temperatureAlertControlsCell.slider.selectedMinValue = CGFloat(lower.value)
        } else {
            let lower: CGFloat = CGFloat(temperatureUnit.alertRange.lowerBound)
            temperatureAlertControlsCell.slider.selectedMinValue = lower
        }
    }

    private func updateUITemperatureUpperBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel?.temperatureUnit.value else {
            temperatureAlertControlsCell.slider.maxValue = 85
            temperatureAlertControlsCell.slider.selectedMaxValue = 85
            return
        }
        if let upper = viewModel?.celsiusUpperBound.value?.converted(to: temperatureUnit.unitTemperature) {
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
           let l = viewModel?.celsiusLowerBound.value?.converted(to: tu),
           let u = viewModel?.celsiusUpperBound.value?.converted(to: tu) {
            let format = "TagSettings.Alerts.Temperature.description".localized()
            temperatureAlertHeaderCell.descriptionLabel.text = String(format: format, l.value, u.value)
        } else {
            temperatureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }
    // MARK: - updateUIHumidity
    private func updateUIHumidityLowerBound() {
        guard isViewLoaded else { return }
        guard let hu = viewModel?.humidityUnit.value else {
            humidityAlertControlsCell.slider.selectedMinValue = 0
            return
        }
        if let lower = viewModel?.humidityLowerBound.value {
            switch hu {
            case .gm3:
                humidityAlertControlsCell.slider.selectedMinValue = CGFloat(lower.converted(to: .absolute).value)
            default:
                if let t = viewModel?.temperature.value {
                    let minValue: Double = lower.converted(to: .relative(temperature: t)).value
                    humidityAlertControlsCell.slider.selectedMinValue = CGFloat(minValue * 100)
                } else {
                    humidityAlertControlsCell.slider.selectedMinValue = CGFloat(hu.alertRange.lowerBound)
                }
            }
        } else {
            humidityAlertControlsCell.slider.selectedMinValue = CGFloat(hu.alertRange.lowerBound)
        }
    }

    private func updateUIHumidityUpperBound() {
        guard isViewLoaded else { return }
        guard let hu = viewModel?.humidityUnit.value else {
            humidityAlertControlsCell.slider.selectedMaxValue = 40
            return
        }
        if let upper = viewModel?.humidityUpperBound.value {
            switch hu {
            case .gm3:
                humidityAlertControlsCell.slider.selectedMaxValue = CGFloat(upper.converted(to: .absolute).value)
            default:
                if let t = viewModel?.temperature.value {
                    let maxValue: Double = upper.converted(to: .relative(temperature: t)).value
                    humidityAlertControlsCell.slider.selectedMaxValue = CGFloat(maxValue * 100)
                } else {
                    humidityAlertControlsCell.slider.selectedMaxValue = CGFloat(hu.alertRange.upperBound)
                }
            }
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
        if let hu = viewModel?.humidityUnit.value,
           let l = viewModel?.humidityLowerBound.value,
           let u = viewModel?.humidityUpperBound.value {
            let format = "TagSettings.Alerts.Humidity.description".localized()
            let description: String
            if hu == .gm3 {
                let la: Double = l.converted(to: .absolute).value
                let ua: Double = u.converted(to: .absolute).value
                description = String(format: format, la, ua)
            } else {
                if let t = viewModel?.temperature.value {
                    let lr: Double = l.converted(to: .relative(temperature: t)).value * 100.0
                    let ur: Double = u.converted(to: .relative(temperature: t)).value * 100.0
                    description = String(format: format, lr, ur)
                } else {
                    description = alertOffString.localized()
                }
            }
            humidityAlertHeaderCell.descriptionLabel.text = description
        } else {
            humidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }

    // MARK: - updateUIPressure
    private func updateUIPressureLowerBound() {
        guard isViewLoaded else { return }
        guard let pu = viewModel?.pressureUnit.value else {
            pressureAlertControlsCell.slider.selectedMinValue = 300
            return
        }
        if let lower = viewModel?.pressureLowerBound.value?.converted(to: pu).value {
            pressureAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
        } else {
            pressureAlertControlsCell.slider.selectedMinValue = CGFloat(pu.alertRange.lowerBound)
        }
    }

    private func updateUIPressureUpperBound() {
        guard isViewLoaded else { return }
        guard let pu = viewModel?.pressureUnit.value else {
            pressureAlertControlsCell.slider.selectedMaxValue = 1100
            return
        }
        if let upper = viewModel?.pressureUpperBound.value?.converted(to: pu).value {
            pressureAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
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
           let l = viewModel?.pressureLowerBound.value?.converted(to: pu),
           let u = viewModel?.pressureUpperBound.value?.converted(to: pu) {
            let format = "TagSettings.Alerts.Pressure.description".localized()
            pressureAlertHeaderCell.descriptionLabel.text = String(format: format, l.value, u.value)
        } else {
            pressureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
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
