// swiftlint:disable file_length
import UIKit
import RangeSeekSlider
import RuuviOntology
import RuuviService

// IMPORTANT: -
// TODO: @prioyonto - CLEAN UP AND REAFCTOR THIS CLASS OVERALL.

enum TagSettingsTableSection: Int {
    case image = 0
    case general = 1
    case connection = 2
    case alerts = 3
    case offsetCorrection = 4
    case moreInfo = 5
    case firmware = 6
    case remove = 7

    static func section(for sectionIndex: Int) -> TagSettingsTableSection {
        return TagSettingsTableSection(rawValue: sectionIndex) ?? .general
    }

    static func showOwner(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.isAuthorized.value == true
    }

    static func showShare(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.canShareTag.value == true
    }

    static func showOffsetCorrection(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.isOwner.value == true
    }
}

class TagSettingsTableViewController: UITableViewController {
    var output: TagSettingsViewOutput!

    @IBOutlet weak var movementAlertControlsCell: TagSettingsAlertDetailsCell!
    @IBOutlet weak var movementAlertHeaderCell: TagSettingsAlertHeaderCell!

    @IBOutlet weak var connectionAlertControlsCell: TagSettingsAlertDetailsCell!
    @IBOutlet weak var connectionAlertHeaderCell: TagSettingsAlertHeaderCell!

    @IBOutlet weak var pressureAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var pressureAlertControlsCell: TagSettingsAlertDetailsCell!

    @IBOutlet weak var temperatureAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var temperatureAlertControlsCell: TagSettingsAlertDetailsCell!

    @IBOutlet weak var rhAlertHeaderCell: TagSettingsAlertHeaderCell!
    @IBOutlet weak var rhAlertControlsCell: TagSettingsAlertDetailsCell!

    @IBOutlet weak var networkOwnerCell: UITableViewCell!
    @IBOutlet weak var networkOwnerLabel: UILabel!
    @IBOutlet weak var networkOwnerValueLabel: UILabel!

    @IBOutlet weak var shareCell: UITableViewCell!
    @IBOutlet weak var shareTitleLabel: UILabel!
    @IBOutlet weak var shareValueLabel: UILabel!

    @IBOutlet weak var keepConnectionSwitch: UISwitch!
    @IBOutlet weak var keepConnectionTitleLabel: UILabel!
    @IBOutlet weak var keepConnectionAnimatingDotsView: RUAnimatingDotsView!

    @IBOutlet weak var dataSourceTitleLabel: UILabel!
    @IBOutlet weak var dataSourceValueLabel: UILabel!

    @IBOutlet weak var macValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var txPowerValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var msnValueLabelTrailing: NSLayoutConstraint!
    @IBOutlet weak var msnCell: UITableViewCell!
    @IBOutlet weak var txPowerCell: UITableViewCell!
    @IBOutlet weak var macAddressCell: UITableViewCell!
    @IBOutlet weak var tagNameCell: UITableViewCell!
    @IBOutlet weak var accelerationXValueLabel: UILabel!
    @IBOutlet weak var accelerationYValueLabel: UILabel!
    @IBOutlet weak var accelerationZValueLabel: UILabel!
    @IBOutlet weak var batteryStatusLabel: UILabel!
    @IBOutlet weak var voltageValueLabel: UILabel!
    @IBOutlet weak var macAddressValueLabel: UILabel!
    @IBOutlet weak var rssiValueLabel: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var uploadBackgroundIndicatorView: UIView!
    @IBOutlet weak var uploadBackgroundProgressLabel: UILabel!
    @IBOutlet weak var tagNameValueLabel: UILabel!
    @IBOutlet weak var firmwareVersionValueLabel: UILabel!
    @IBOutlet weak var dataFormatValueLabel: UILabel!
    @IBOutlet weak var msnValueLabel: UILabel!
    @IBOutlet weak var txPowerValueLabel: UILabel!
    @IBOutlet weak var backgroundImageLabel: UILabel!
    @IBOutlet weak var tagNameTitleLabel: UILabel!
    @IBOutlet weak var macAddressTitleLabel: UILabel!
    @IBOutlet weak var rssiTitleLabel: UILabel!
    @IBOutlet weak var firmwareVersionTitleLabel: UILabel!
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

    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var exportBarButtonItem: UIBarButtonItem!

    @IBOutlet weak var removeThisSensorLabel: UILabel!
    @IBOutlet weak var removeCell: UITableViewCell!

    var viewModel: TagSettingsViewModel? {
        didSet {
            bindViewModel()
        }
    }

    var measurementService: RuuviServiceMeasurement!

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.default
    }

    private let sectionHeaderReuseIdentifier = "TagSettingsSectionHeaderView"
    private let alertPlaceholder = "TagSettings.Alert.CustomDescription.placeholder".localized()
    private let alertOffImage = UIImage(named: "icon-alert-off")
    private let alertOnImage = UIImage(named: "icon-alert-on")
    private let alertActiveImage = UIImage(named: "icon-alert-active")

    private static var localizedCache: LocalizedCache = LocalizedCache()
    /// The limit for the tag name is 32 characters
    private var tagNameTextField = UITextField()
    private let tagNameCharaterLimit: Int = 32
    private var customAlertDescriptionTextField = UITextField()
    private let customAlertDescriptionCharacterLimit = 32
    private var alertMinRangeTextField = UITextField()
    private var alertMaxRangeTextField = UITextField()
}

// MARK: - TagSettingsViewInput
extension TagSettingsTableViewController: TagSettingsViewInput {
    /// If settings page is opened using the alert bell tableview will be
    /// scrolled to the alert settings section
    func updateScrollPosition(scrollToAlert: Bool) {
        if scrollToAlert {
            let indexPath = IndexPath(row: 0, section: 2)
            tableView.scrollToRow(at: indexPath, at: .top, animated: false)
        }
    }

    func localize() {
        navigationItem.title = "TagSettings.navigationItem.title".localized()
        backgroundImageLabel.text = "TagSettings.backgroundImageLabel.text".localized()
        tagNameTitleLabel.text = "TagSettings.tagNameTitleLabel.text".localized()
        rssiTitleLabel.text = "TagSettings.rssiTitleLabel.text".localized()
        macAddressTitleLabel.text = "TagSettings.macAddressTitleLabel.text".localized()
        dataFormatTitleLabel.text = "TagSettings.dataFormatTitleLabel.text".localized()
        batteryVoltageTitleLabel.text = "TagSettings.batteryVoltageTitleLabel.text".localized()
        accelerationXTitleLabel.text = "TagSettings.accelerationXTitleLabel.text".localized()
        accelerationYTitleLabel.text = "TagSettings.accelerationYTitleLabel.text".localized()
        accelerationZTitleLabel.text = "TagSettings.accelerationZTitleLabel.text".localized()
        txPowerTitleLabel.text = "TagSettings.txPowerTitleLabel.text".localized()
        msnTitleLabel.text = "TagSettings.msnTitleLabel.text".localized()
        dataSourceTitleLabel.text = "TagSettings.dataSourceTitleLabel.text".localized()

        updateUITemperatureAlertDescription()
        keepConnectionTitleLabel.text = "TagSettings.PairAndBackgroundScan.title".localized()
        rhAlertHeaderCell.titleLabel.text
            = "TagSettings.AirHumidityAlert.title".localized()
        pressureAlertHeaderCell.titleLabel.text
            = "TagSettings.PressureAlert.title".localized()
        connectionAlertHeaderCell.titleLabel.text = "TagSettings.ConnectionAlert.title".localized()
        movementAlertHeaderCell.titleLabel.text = "TagSettings.MovementAlert.title".localized()

        temperatureAlertControlsCell.setCustomDescription(with: alertPlaceholder)
        rhAlertControlsCell.setCustomDescription(with: alertPlaceholder)
        pressureAlertControlsCell.setCustomDescription(with: alertPlaceholder)
        connectionAlertControlsCell.setCustomDescription(with: alertPlaceholder)
        connectionAlertControlsCell.setAlertAddtionalText(with: "TagSettings.Alerts.Connection.description".localized())
        movementAlertControlsCell.setCustomDescription(with: alertPlaceholder)
        movementAlertControlsCell.setAlertAddtionalText(with: "TagSettings.Alerts.Movement.description".localized())

        temperatureOffsetTitleLabel.text = "TagSettings.OffsetCorrection.Temperature".localized()
        humidityOffsetTitleLabel.text = "TagSettings.OffsetCorrection.Humidity".localized()
        pressureOffsetTitleLabel.text = "TagSettings.OffsetCorrection.Pressure".localized()

        firmwareVersionTitleLabel.text = "TagSettings.Firmware.CurrentVersion".localized()
        updateFirmwareTitleLabel.text = "TagSettings.Firmware.UpdateFirmware".localized()

        networkOwnerLabel.text = "TagSettings.NetworkInfo.Owner".localized()

        shareTitleLabel.text = "TagSettings.Share.title".localized()

        removeThisSensorLabel.text = "TagSettings.RemoveThisSensor.title".localized()
        tableView.reloadData()
    }

    func showTagRemovalConfirmationDialog(isOwner: Bool) {
        let title = "TagSettings.confirmTagRemovalDialog.title".localized()
        let message = isOwner ?
        "TagSettings.confirmTagRemovalDialog.message".localized() :
        "TagSettings.confirmSharedTagRemovalDialog.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: isOwner ? "Confirm".localized() : "OK".localized(),
                                           style: .destructive,
                                           handler: { [weak self] _ in
                                            self?.output.viewDidConfirmTagRemoval()
                                           }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showUnclaimAndRemoveConfirmationDialog() {
        let title = "TagSettings.confirmTagRemovalDialog.title".localized()
        let message = "TagSettings.confirmTagUnclaimAndRemoveDialog.message".localized()
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

    func showKeepConnectionTimeoutDialog() {
        let message = "TagSettings.PairError.Timeout.description".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func resetKeepConnectionSwitch() {
        keepConnectionSwitch.setOn(false, animated: true)
        keepConnectionSwitch.isEnabled = true
    }

    func showKeepConnectionCloudModeDialog() {
        let message = "TagSettings.PairError.CloudMode.description".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "OK".localized(),
                                           style: .cancel,
                                           handler: { [weak self] _ in
            self?.resetKeepConnectionSwitch()
        }))
        present(controller, animated: true)
    }

    func stopKeepConnectionAnimatingDots() {
        keepConnectionAnimatingDotsView.stopAnimating()
    }

    func startKeepConnectionAnimatingDots() {
        keepConnectionAnimatingDotsView.startAnimating()
    }

    func showExportSheet(with path: URL) {
        let vc = UIActivityViewController(activityItems: [path], applicationActivities: [])
        vc.excludedActivityTypes = [
            UIActivity.ActivityType.assignToContact,
            UIActivity.ActivityType.saveToCameraRoll,
            UIActivity.ActivityType.postToFlickr,
            UIActivity.ActivityType.postToVimeo,
            UIActivity.ActivityType.postToTencentWeibo,
            UIActivity.ActivityType.postToTwitter,
            UIActivity.ActivityType.postToFacebook,
            UIActivity.ActivityType.openInIBooks
        ]
        vc.popoverPresentationController?.barButtonItem = exportBarButtonItem
        vc.popoverPresentationController?.permittedArrowDirections = .up
        present(vc, animated: true)
    }
}

// MARK: - Sensor name rename dialog
extension TagSettingsTableViewController {
    private func showSensorNameRenameDialog(name: String?) {
        let alert = UIAlertController(title: "TagSettings.tagNameTitleLabel.text".localized(),
                                      message: "TagSettings.tagNameTitleLabel.rename.text".localized(),
                                      preferredStyle: .alert)
        alert.addTextField { [weak self] alertTextField in
            guard let self = self else { return }
            alertTextField.delegate = self
            alertTextField.text = name
            self.tagNameTextField = alertTextField
        }
        let action = UIAlertAction(title: "OK".localized(), style: .default) { [weak self] _ in
            guard let self = self else { return }
            guard let name = self.tagNameTextField.text, !name.isEmpty else { return }
            self.output.viewDidChangeTag(name: name)
        }
        let cancelAction = UIAlertAction(title: "Cancel".localized(), style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Sensor alert custom description dialog
extension TagSettingsTableViewController {
    private func showSensorCustomAlertDescriptionDialog(description: String?,
                                                        sender: TagSettingsAlertDetailsCell) {
        let alert = UIAlertController(title: "TagSettings.Alert.CustomDescription.title".localized(),
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addTextField { [weak self] alertTextField in
            guard let self = self else { return }
            alertTextField.delegate = self
            alertTextField.text = description
            self.customAlertDescriptionTextField = alertTextField
        }

        let action = UIAlertAction(title: "OK".localized(), style: .default) { [weak self] _ in
            guard let self = self else { return }
            let inputText = self.customAlertDescriptionTextField.text

            switch sender {
            case self.temperatureAlertControlsCell:
                self.viewModel?.temperatureAlertDescription.value = inputText
            case self.rhAlertControlsCell:
                self.viewModel?.relativeHumidityAlertDescription.value = inputText
            case self.pressureAlertControlsCell:
                self.viewModel?.pressureAlertDescription.value = inputText
            case self.connectionAlertControlsCell:
                self.viewModel?.connectionAlertDescription.value = inputText
            case self.movementAlertControlsCell:
                self.viewModel?.movementAlertDescription.value = inputText
            default:
                break
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel".localized(), style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Sensor alert range settings
extension TagSettingsTableViewController {
    // swiftlint:disable:next function_parameter_count function_body_length cyclomatic_complexity
    private func showSensorCustomAlertRangeDialog(title: String?,
                                                  minimumBound: Double,
                                                  maximumBound: Double,
                                                  currentLowerBound: Double?,
                                                  currentUpperBound: Double?,
                                                  sender: TagSettingsAlertDetailsCell) {
        let alert = UIAlertController(title: title,
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addTextField { [weak self] alertTextField in
            guard let self = self else { return }
            alertTextField.delegate = self
            let format = "TagSettings.AlertSettings.Dialog.Min".localized()
            alertTextField.placeholder = String(format: format, minimumBound)
            alertTextField.keyboardType = .decimalPad
            self.alertMinRangeTextField = alertTextField
            if minimumBound < 0 {
                self.alertMinRangeTextField.addNumericAccessory()
            }
            switch sender {
            case self.temperatureAlertControlsCell:
                alertTextField.text = self.measurementService.string(for: currentLowerBound)
            case self.rhAlertControlsCell:
                alertTextField.text = self.measurementService.string(for: currentLowerBound)
            case self.pressureAlertControlsCell:
                alertTextField.text = self.measurementService.string(for: currentLowerBound)
            default:
                break
            }
        }

        alert.addTextField { [weak self] alertTextField in
            guard let self = self else { return }
            alertTextField.delegate = self
            let format = "TagSettings.AlertSettings.Dialog.Max".localized()
            alertTextField.placeholder = String(format: format, maximumBound)
            alertTextField.keyboardType = .decimalPad
            self.alertMaxRangeTextField = alertTextField
            if maximumBound < 0 {
                self.alertMaxRangeTextField.addNumericAccessory()
            }
            switch sender {
            case self.temperatureAlertControlsCell:
                alertTextField.text = self.measurementService.string(for: currentUpperBound)
            case self.rhAlertControlsCell:
                alertTextField.text = self.measurementService.string(for: currentUpperBound)
            case self.pressureAlertControlsCell:
                alertTextField.text = self.measurementService.string(for: currentUpperBound)
            default:
                break
            }
        }

        let action = UIAlertAction(title: "OK".localized(), style: .default) { [weak self] _ in
            guard let self = self else { return }
            guard let minimumInputText = self.alertMinRangeTextField.text,
                  minimumInputText.doubleValue >= minimumBound else {
                return
            }

            guard let maximumInputText = self.alertMaxRangeTextField.text,
                  maximumInputText.doubleValue <= maximumBound else {
                return
            }

            self.didSetAlertRange(sender: sender,
                                  didSlideTo: minimumInputText.doubleValue,
                                  maxValue: maximumInputText.doubleValue )
        }
        let cancelAction = UIAlertAction(title: "Cancel".localized(), style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
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

    @IBAction func randomizeBackgroundButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToRandomizeBackground()
    }

    @IBAction func selectBackgroundButtonTouchUpInside(_ sender: UIButton) {
        output.viewDidAskToSelectBackground(sourceView: sender)
    }

    @IBAction func keepConnectionSwitchValueChanged(_ sender: Any) {
        output.viewDidTriggerKeepConnection(isOn: keepConnectionSwitch.isOn)
    }

    @IBAction func exportBarButtonItemAction(_ sender: Any) {
        output.viewDidTapOnExport()
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
            showSensorNameRenameDialog(name: viewModel?.name.value)
        case networkOwnerCell:
            output.viewDidTapOnOwner()
        case shareCell:
            output.viewDidTapShareButton()
        case temperatureAlertHeaderCell:
            temperatureAlertHeaderCell.toggle()
        case pressureAlertHeaderCell:
            pressureAlertHeaderCell.toggle()
        case rhAlertHeaderCell:
            rhAlertHeaderCell.toggle()
        case connectionAlertHeaderCell:
            connectionAlertHeaderCell.toggle()
        case movementAlertHeaderCell:
            movementAlertHeaderCell.toggle()
        case macAddressCell:
            output.viewDidTapOnMacAddress()
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
        case removeCell:
            output.viewDidAskToRemoveRuuviTag()
        default:
            break
        }
    }
    // swiftlint:enable cyclomatic_complexity

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let section = TagSettingsTableSection.section(for: section)
        switch section {
        case .connection:
            return "TagSettings.PairAndBackgroundScan.description".localized()
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = TagSettingsTableSection.section(for: section)
        guard let header = tableView
            .dequeueReusableHeaderFooterView(withIdentifier: sectionHeaderReuseIdentifier)
                as? TagSettingsSectionHeaderView
        else {
            return nil
        }

        switch section {
        case .general:
            header.titleLabel.text = "TagSettings.SectionHeader.General.title".localized().capitalized
            header.noValuesView.isHidden = true
        case .connection:
            header.titleLabel.text = "TagSettings.SectionHeader.BTConnection.title".localized().capitalized
            header.noValuesView.isHidden = true
        case .alerts:
            header.titleLabel.text = "TagSettings.Label.alerts.text".localized().capitalized
            header.noValuesView.isHidden = true
        case .offsetCorrection:
            let showOffsetCorrection = TagSettingsTableSection.showOffsetCorrection(for: viewModel)
            header.titleLabel.text = showOffsetCorrection ?
                "TagSettings.SectionHeader.OffsetCorrection.Title".localized().capitalized : nil
            header.noValuesView.isHidden = true
        case .moreInfo:
            header.titleLabel.text = "TagSettings.Label.moreInfo.text".localized().capitalized
            header.delegate = self
            header.noValuesView.isHidden = viewModel?.version.value == 5
        case .firmware:
            header.titleLabel.text = "TagSettings.SectionHeader.Firmware.title".localized().capitalized
            header.noValuesView.isHidden = true
        case .remove:
            header.titleLabel.text = "TagSettings.SectionHeader.Remove.title".localized().capitalized
            header.noValuesView.isHidden = true
        default:
            return nil
        }
        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let defaultHeaderHeight: CGFloat = 32
        let s = TagSettingsTableSection.section(for: section)
        switch s {
        case .offsetCorrection:
            // Toggle it based on sensor owner, if user is sensor owner show it, otherwise hide
            let showOffsetCorrection = TagSettingsTableSection.showOffsetCorrection(for: viewModel)
            return showOffsetCorrection ? defaultHeaderHeight : 0
        default:
            return defaultHeaderHeight
        }
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let sectionIdentifier = TagSettingsTableSection.section(for: section)
        switch sectionIdentifier {
        case .connection:
            return super.tableView(tableView, heightForFooterInSection: section)
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let s = TagSettingsTableSection.section(for: section)
        switch s {
        case .general:
            let showOwner = TagSettingsTableSection.showOwner(for: viewModel)
            let showShare = TagSettingsTableSection.showShare(for: viewModel)
            if showOwner && showShare {
                return 3
            } else if showOwner {
                return 2
            } else {
                return 1
            }
        case .offsetCorrection:
            // Toggle it based on sensor owner, if user is sensor owner show it, otherwise hide
            let showOffsetCorrection = TagSettingsTableSection.showOffsetCorrection(for: viewModel)
            return showOffsetCorrection ? super.tableView(tableView, numberOfRowsInSection: section) : 0
        default:
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        let headerHeight: CGFloat = 44
        let controlsHeight: CGFloat = 192
        let controlsHeightWithoutRangeSlider: CGFloat = 130
        switch cell {
            // Headers
        case temperatureAlertHeaderCell:
            return headerHeight
        case rhAlertHeaderCell:
            return (viewModel?.humidityOffsetCorrectionVisible.value ?? false) ? headerHeight : 0
        case pressureAlertHeaderCell:
            return (viewModel?.pressureOffsetCorrectionVisible.value ?? false) ? headerHeight : 0
        case connectionAlertHeaderCell:
            return headerHeight
        case movementAlertHeaderCell:
            return viewModel?.movementCounter.value != nil ? headerHeight : 0
        // Controls
        case temperatureAlertControlsCell:
            temperatureAlertControlsCell.hideNoticeView()
            temperatureAlertControlsCell.showAlertRangeSetter()
            temperatureAlertControlsCell.hideAdditionalTextview()
            return (viewModel?.isTemperatureAlertExpanded.value ?? false) ? controlsHeight : 0
        case rhAlertControlsCell:
            rhAlertControlsCell.hideNoticeView()
            rhAlertControlsCell.showAlertRangeSetter()
            rhAlertControlsCell.hideAdditionalTextview()
            return (viewModel?.isRelativeHumidityAlertExpanded.value ?? false) ? controlsHeight : 0
        case pressureAlertControlsCell:
            pressureAlertControlsCell.hideNoticeView()
            pressureAlertControlsCell.showAlertRangeSetter()
            pressureAlertControlsCell.hideAdditionalTextview()
            return (viewModel?.isPressureAlertExpanded.value ?? false) ? controlsHeight : 0
        case connectionAlertControlsCell:
            connectionAlertControlsCell.hideNoticeView()
            connectionAlertControlsCell.hideAlertRangeSetter()
            connectionAlertControlsCell.showAdditionalTextview()
            return (viewModel?.isConnectionAlertExpanded.value ?? false) ? controlsHeightWithoutRangeSlider : 0
        case movementAlertControlsCell:
            movementAlertControlsCell.hideNoticeView()
            movementAlertControlsCell.hideAlertRangeSetter()
            movementAlertControlsCell.showAdditionalTextview()
            return (viewModel?.isMovementAlertExpanded.value ?? false) ? controlsHeightWithoutRangeSlider : 0
        case humidityOffsetCorrectionCell:
            return (viewModel?.humidityOffsetCorrectionVisible.value ?? false) ? 44 : 0
        case pressureOffsetCorrectionCell:
            return (viewModel?.pressureOffsetCorrectionVisible.value ?? false) ? 44 : 0
        default:
            return 44
        }
    }
}

// MARK: - TagSettingsSectionHeaderViewDelegate
extension TagSettingsTableViewController: TagSettingsSectionHeaderViewDelegate {
    func didTapSectionHeaderMoreInfo(headerView: TagSettingsSectionHeaderView, didTapOnInfo button: UIButton) {
        output.viewDidTapOnNoValuesView()
    }
}

// MARK: - TagSettingsAlertHeaderCellDelegate
extension TagSettingsTableViewController: TagSettingsAlertHeaderCellDelegate {
    func tagSettingsAlertHeader(cell: TagSettingsAlertHeaderCell, didToggle isOn: Bool) {
        switch cell {
        case temperatureAlertHeaderCell:
            viewModel?.isTemperatureAlertExpanded.value = isOn
        case rhAlertHeaderCell:
            viewModel?.isRelativeHumidityAlertExpanded.value = isOn
        case pressureAlertHeaderCell:
            viewModel?.isPressureAlertExpanded.value = isOn
        case connectionAlertHeaderCell:
            viewModel?.isConnectionAlertExpanded.value = isOn
        case movementAlertHeaderCell:
            viewModel?.isMovementAlertExpanded.value = isOn
        default:
            break
        }
    }
}

// MARK: - TagSettingsAlertDetailsCellDelegate
extension TagSettingsTableViewController: TagSettingsAlertDetailsCellDelegate {

    func didSelectSetCustomDescription(sender: TagSettingsAlertDetailsCell) {
        switch sender {
        case temperatureAlertControlsCell:
            showSensorCustomAlertDescriptionDialog(description:
                                                    viewModel?.temperatureAlertDescription.value,
                                                   sender: sender)
        case rhAlertControlsCell:
            showSensorCustomAlertDescriptionDialog(description:
                                                    viewModel?.relativeHumidityAlertDescription.value,
                                                   sender: sender)
        case pressureAlertControlsCell:
            showSensorCustomAlertDescriptionDialog(description:
                                                    viewModel?.pressureAlertDescription.value,
                                                   sender: sender)
        case connectionAlertControlsCell:
            showSensorCustomAlertDescriptionDialog(description:
                                                    viewModel?.connectionAlertDescription.value,
                                                   sender: sender)
        case movementAlertControlsCell:
            showSensorCustomAlertDescriptionDialog(description:
                                                    viewModel?.movementAlertDescription.value,
                                                   sender: sender)
        default:
            break
        }
    }

    func didSelectAlertLimitDescription(sender: TagSettingsAlertDetailsCell) {

        switch sender {
        case temperatureAlertControlsCell:
            showTemparatureAlertSetPopup(sender: sender)
        case rhAlertControlsCell:
            showHumidityAlertSetDialog(sender: sender)
        case pressureAlertControlsCell:
            showPressureAlertSetDialog(sender: sender)

        default:
            break
        }
    }

    func didChangeAlertState(sender: TagSettingsAlertDetailsCell,
                             didToggle isOn: Bool) {
        switch sender {
        case temperatureAlertControlsCell:
            viewModel?.isTemperatureAlertOn.value = isOn
        case rhAlertControlsCell:
            viewModel?.isRelativeHumidityAlertOn.value = isOn
        case pressureAlertControlsCell:
            viewModel?.isPressureAlertOn.value = isOn
        case connectionAlertControlsCell:
            viewModel?.isConnectionAlertOn.value = isOn
        case movementAlertControlsCell:
            viewModel?.isMovementAlertOn.value = isOn
        default:
            break
        }
    }

    func didSetAlertRange(sender: TagSettingsAlertDetailsCell,
                          didSlideTo minValue: CGFloat,
                          maxValue: CGFloat) {
        switch sender {
        case temperatureAlertControlsCell:
            if let tu = viewModel?.temperatureUnit.value {
                viewModel?.temperatureLowerBound.value = Temperature(Double(minValue), unit: tu.unitTemperature)
                viewModel?.temperatureUpperBound.value = Temperature(Double(maxValue), unit: tu.unitTemperature)
            }
        case rhAlertControlsCell:
            viewModel?.relativeHumidityLowerBound.value = Double(minValue)
            viewModel?.relativeHumidityUpperBound.value = Double(maxValue)
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
        let moreInfoSectionNib = UINib(nibName: "TagSettingsSectionHeaderView", bundle: nil)
        tableView.register(moreInfoSectionNib, forHeaderFooterViewReuseIdentifier: sectionHeaderReuseIdentifier)
        temperatureAlertHeaderCell.delegate = self
        temperatureAlertControlsCell.delegate = self
        rhAlertHeaderCell.delegate = self
        rhAlertControlsCell.delegate = self
        pressureAlertHeaderCell.delegate = self
        pressureAlertControlsCell.delegate = self
        connectionAlertHeaderCell.delegate = self
        connectionAlertControlsCell.delegate = self
        movementAlertHeaderCell.delegate = self
        movementAlertControlsCell.delegate = self
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
        temperatureAlertControlsCell.alertLimitSliderView.minValue = CGFloat(tu.alertRange.lowerBound)
        temperatureAlertControlsCell.alertLimitSliderView.maxValue = CGFloat(tu.alertRange.upperBound)

        let rhRange = HumidityUnit.percent.alertRange
        rhAlertControlsCell.alertLimitSliderView.minValue = CGFloat(rhRange.lowerBound)
        rhAlertControlsCell.alertLimitSliderView.maxValue = CGFloat(rhRange.upperBound)

        let p = viewModel?.pressureUnit.value ?? .hectopascals
        pressureAlertControlsCell.alertLimitSliderView.minValue = CGFloat(p.alertRange.lowerBound)
        pressureAlertControlsCell.alertLimitSliderView.maxValue = CGFloat(p.alertRange.upperBound)
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
        bindPressureAlertCells()
        bindConnectionAlertCells()
        bindMovementAlertCell()

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

        tableView.bind(viewModel.humidityOffsetCorrectionVisible) { tableView, _ in
            tableView.reloadData()
        }

        tableView.bind(viewModel.pressureOffsetCorrectionVisible) { tableView, _ in
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
        tagNameValueLabel.bind(viewModel.name) { $0.text = $1?.trimmingCharacters(in: .whitespacesAndNewlines) }

        networkOwnerCell.bind(viewModel.isClaimedTag) { cell, isClaimed in
            cell.accessoryType = (isClaimed ?? false) ? .none : .disclosureIndicator
        }

        let emptyValueString = "TagSettings.EmptyValue.sign"

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

        batteryStatusLabel.bind(viewModel.batteryNeedsReplacement) { label, needsReplacement in
            if let needsReplacement = needsReplacement {
                label.isHidden = false
                // swiftlint:disable:next line_length
                label.text = needsReplacement ? "(\("TagSettings.BatteryStatusLabel.Replace.message".localized()))" : "(\("TagSettings.BatteryStatusLabel.Ok.message".localized()))"
                label.textColor = needsReplacement ? .red : .green
            } else {
                label.isHidden = true
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

        firmwareVersionValueLabel.bind(viewModel.firmwareVersion) { (label, version) in
            if let version = version {
                label.text = version
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

        keepConnectionSwitch.bind(viewModel.keepConnection) { (view, keepConnection) in
            view.isOn = keepConnection.bound
        }

        keepConnectionSwitch.bind(viewModel.isConnected) { (view, isConnected) in
            view.isOn = isConnected.bound
            view.isEnabled = true
        }

        let keepConnection = viewModel.keepConnection
        keepConnectionTitleLabel.bind(viewModel.isConnected) { [weak keepConnection] (label, isConnected) in
            let keep = keepConnection?.value ?? false
            if isConnected.bound {
                // Connected state
                label.text = "TagSettings.PairAndBackgroundScan.Paired.title".localized()
                self.keepConnectionAnimatingDotsView.stopAnimating()
            } else if keep {
                // When trying to connect
                label.text = "TagSettings.PairAndBackgroundScan.Pairing.title".localized()
                self.keepConnectionAnimatingDotsView.startAnimating()
            } else {
                // Disconnected state
                label.text = "TagSettings.PairAndBackgroundScan.Unpaired.title".localized()
                self.keepConnectionAnimatingDotsView.stopAnimating()
            }
        }

        let isConnected = viewModel.isConnected
        keepConnectionTitleLabel.bind(viewModel.keepConnection) { [weak isConnected] (label, keepConnection) in
            let isConnected = isConnected?.value ?? false
            if isConnected {
                // Connected state
                label.text = "TagSettings.PairAndBackgroundScan.Paired.title".localized()
                self.keepConnectionAnimatingDotsView.stopAnimating()
            } else if keepConnection.bound {
                // When trying to connect
                label.text = "TagSettings.PairAndBackgroundScan.Pairing.title".localized()
                self.keepConnectionAnimatingDotsView.startAnimating()
            } else {
                // Disconnected state
                label.text = "TagSettings.PairAndBackgroundScan.Unpaired.title".localized()
                self.keepConnectionAnimatingDotsView.stopAnimating()
            }
        }

        bindOffsetCorrectionCells()
    }

    // swiftlint:disable:next function_body_length
    private func bindTemperatureAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }

        temperatureAlertHeaderCell.mutedTillLabel.bind(viewModel.temperatureAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                label.text = AppDateFormatter.shared.shortTimeString(from: date)
            } else {
                label.isHidden = true
            }
        }

        temperatureAlertHeaderCell.alertStateImageView.bind(viewModel.isTemperatureAlertOn) {
            [weak self] (imageView, isOn) in
            imageView.image = isOn.bound ? self?.alertOnImage : nil
        }

        temperatureAlertHeaderCell.alertStateImageView.bind(viewModel.temperatureAlertState) {
            [weak self] (imageView, state) in
            imageView.layer.removeAllAnimations()
            if let state = state {
                switch state {
                case .empty:
                    imageView.image = nil
                case .registered:
                    imageView.alpha = 1.0
                    imageView.image = self?.alertOnImage
                case .firing:
                    if imageView.image != self?.alertActiveImage {
                        imageView.image = self?.alertActiveImage
                        UIView.animate(withDuration: 0.5,
                                      delay: 0,
                                      options: [.repeat, .autoreverse],
                                      animations: { [weak imageView] in
                                        imageView?.alpha = 0.0
                                    })
                    }
                }
            }
        }

        temperatureAlertControlsCell.statusSwitch.bind(viewModel.isTemperatureAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        temperatureAlertControlsCell.statusLabel.bind(viewModel.isTemperatureAlertOn) { (label, isOn) in
            label.text = isOn.bound ? "On".localized() : "Off".localized()
        }

        temperatureAlertControlsCell.alertLimitSliderView.bind(viewModel.temperatureLowerBound) { [weak self] (_, _) in
            self?.updateUITemperatureLowerBound()
            self?.updateUITemperatureAlertDescription()
        }

        temperatureAlertControlsCell.alertLimitSliderView.bind(viewModel.temperatureUpperBound) { [weak self] (_, _) in
            self?.updateUITemperatureUpperBound()
            self?.updateUITemperatureAlertDescription()
        }

        temperatureAlertHeaderCell.titleLabel.bind(viewModel.temperatureUnit) { (label, temperatureUnit) in
            let title = "TagSettings.temperatureAlertTitleLabel.text"
            label.text = String(format: title.localized(), temperatureUnit?.symbol ?? "N/A".localized())
        }

        temperatureAlertControlsCell.alertLimitSliderView.bind(viewModel.temperatureUnit) { (slider, temperatureUnit) in
            if let tu = temperatureUnit {
                slider.minValue = CGFloat(tu.alertRange.lowerBound)
                slider.maxValue = CGFloat(tu.alertRange.upperBound)
            }
        }

        temperatureAlertControlsCell
            .setCustomDescriptionView
            .titleLabel.bind(viewModel.temperatureAlertDescription) {
                [weak self] (label, temperatureAlertDescription) in
                if temperatureAlertDescription.hasText() {
                    label.text = temperatureAlertDescription
                } else {
                    label.text = self?.alertPlaceholder
                }
            }

        tableView.bind(viewModel.isTemperatureAlertExpanded) { tableView, _ in
            if tableView.window != nil {
                tableView.reloadData()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindConnectionAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }

        connectionAlertHeaderCell.mutedTillLabel.bind(viewModel.connectionAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                label.text = AppDateFormatter.shared.shortTimeString(from: date)
            } else {
                label.isHidden = true
            }
        }

        connectionAlertHeaderCell.alertStateImageView.bind(viewModel.isConnectionAlertOn) {
            [weak self] (imageView, isOn) in
            imageView.image = isOn.bound ? self?.alertOnImage : nil
        }

        connectionAlertHeaderCell.alertStateImageView.bind(viewModel.connectionAlertState) {
            [weak self] (imageView, state) in
            imageView.layer.removeAllAnimations()
            if let state = state {
                switch state {
                case .empty:
                    imageView.image = nil
                case .registered:
                    imageView.alpha = 1.0
                    imageView.image = self?.alertOnImage
                case .firing:
                    if imageView.image != self?.alertActiveImage {
                        imageView.image = self?.alertActiveImage
                        UIView.animate(withDuration: 0.5,
                                      delay: 0,
                                      options: [.repeat, .autoreverse],
                                      animations: { [weak imageView] in
                                        imageView?.alpha = 0.0
                                    })
                    }
                }
            }
        }

        connectionAlertControlsCell.statusSwitch.bind(viewModel.isConnectionAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        connectionAlertControlsCell.statusLabel.bind(viewModel.isConnectionAlertOn) { (label, isOn) in
            label.text = isOn.bound ? "On".localized() : "Off".localized()
        }

        connectionAlertControlsCell.statusSwitch.bind(viewModel.isPushNotificationsEnabled) {
            view, isPushNotificationsEnabled in
            let isPN = isPushNotificationsEnabled ?? false
            let isEnabled = isPN
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        connectionAlertControlsCell.statusLabel.bind(viewModel.isPushNotificationsEnabled) { (label, isOn) in
            label.text = isOn.bound ? "On".localized() : "Off".localized()
        }

        connectionAlertControlsCell
            .setCustomDescriptionView
            .titleLabel.bind(viewModel.connectionAlertDescription) {
                [weak self] (label, connectionAlertDescription) in
                if connectionAlertDescription.hasText() {
                    label.text = connectionAlertDescription
                } else {
                    label.text = self?.alertPlaceholder
                }
            }

        tableView.bind(viewModel.isConnectionAlertExpanded) { tableView, _ in
            if tableView.window != nil {
                tableView.reloadData()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindMovementAlertCell() {
        guard isViewLoaded, let viewModel = viewModel  else { return }

        movementAlertHeaderCell.mutedTillLabel.bind(viewModel.movementAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                label.text = AppDateFormatter.shared.shortTimeString(from: date)
            } else {
                label.isHidden = true
            }
        }
        movementAlertHeaderCell.alertStateImageView.bind(viewModel.isMovementAlertOn) { [weak self] (imageView, isOn) in
            imageView.image = isOn.bound ? self?.alertOnImage : nil
        }

        movementAlertHeaderCell.alertStateImageView.bind(viewModel.movementAlertState) {
            [weak self] (imageView, state) in
            imageView.layer.removeAllAnimations()
            if let state = state {
                switch state {
                case .empty:
                    imageView.image = nil
                case .registered:
                    imageView.alpha = 1.0
                    imageView.image = self?.alertOnImage
                case .firing:
                    if imageView.image != self?.alertActiveImage {
                        imageView.image = self?.alertActiveImage
                        UIView.animate(withDuration: 0.5,
                                      delay: 0,
                                      options: [.repeat, .autoreverse],
                                      animations: { [weak imageView] in
                                        imageView?.alpha = 0.0
                                    })
                    }
                }
            }
        }

        movementAlertControlsCell.statusSwitch.bind(viewModel.isMovementAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        movementAlertControlsCell.statusLabel.bind(viewModel.isMovementAlertOn) { (label, isOn) in
            label.text = isOn.bound ? "On".localized() : "Off".localized()
        }

        movementAlertControlsCell
            .setCustomDescriptionView
            .titleLabel.bind(viewModel.movementAlertDescription) {
                [weak self] (label, movementAlertDescription) in
                if movementAlertDescription.hasText() {
                    label.text = movementAlertDescription
                } else {
                    label.text = self?.alertPlaceholder
                }
            }

        tableView.bind(viewModel.isMovementAlertExpanded) { tableView, _ in
            if tableView.window != nil {
                tableView.reloadData()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindPressureAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }

        pressureAlertHeaderCell.mutedTillLabel.bind(viewModel.pressureAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                label.text = AppDateFormatter.shared.shortTimeString(from: date)
            } else {
                label.isHidden = true
            }
        }
        pressureAlertHeaderCell.alertStateImageView.bind(viewModel.isPressureAlertOn) { [weak self] (imageView, isOn) in
            imageView.image = isOn.bound ? self?.alertOnImage : nil
        }

        pressureAlertHeaderCell.alertStateImageView.bind(viewModel.pressureAlertState) {
            [weak self] (imageView, state) in
            imageView.layer.removeAllAnimations()
            if let state = state {
                switch state {
                case .empty:
                    imageView.image = nil
                case .registered:
                    imageView.alpha = 1.0
                    imageView.image = self?.alertOnImage
                case .firing:
                    if imageView.image != self?.alertActiveImage {
                        imageView.image = self?.alertActiveImage
                        UIView.animate(withDuration: 0.5,
                                      delay: 0,
                                      options: [.repeat, .autoreverse],
                                      animations: { [weak imageView] in
                                        imageView?.alpha = 0.0
                                    })
                    }
                }
            }
        }

        pressureAlertControlsCell.statusSwitch.bind(viewModel.isPressureAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        pressureAlertControlsCell.statusLabel.bind(viewModel.isPressureAlertOn) { (label, isOn) in
            label.text = isOn.bound ? "On".localized() : "Off".localized()
        }

        pressureAlertControlsCell.alertLimitSliderView.bind(viewModel.pressureLowerBound) { [weak self] (_, _) in
            self?.updateUIPressureLowerBound()
            self?.updateUIPressureAlertDescription()
        }

        pressureAlertControlsCell.alertLimitSliderView.bind(viewModel.pressureUpperBound) { [weak self] (_, _) in
            self?.updateUIPressureUpperBound()
            self?.updateUIPressureAlertDescription()
        }

        pressureAlertHeaderCell.titleLabel.bind(viewModel.pressureUnit) { (label, pressureUnit) in
            let title = "TagSettings.PressureAlert.title"
            label.text = String(format: title.localized(), pressureUnit?.symbol ?? "N/A".localized())
        }

        pressureAlertControlsCell.alertLimitSliderView.bind(viewModel.pressureUnit) {
            (slider, pressureUnit) in
            if let pu = pressureUnit {
                slider.minValue = CGFloat(pu.alertRange.lowerBound)
                slider.maxValue = CGFloat(pu.alertRange.upperBound)
            }
        }

        pressureAlertControlsCell
            .setCustomDescriptionView
            .titleLabel.bind(viewModel.pressureAlertDescription) {
                [weak self] (label, pressureAlertDescription) in
                if pressureAlertDescription.hasText() {
                    label.text = pressureAlertDescription
                } else {
                    label.text = self?.alertPlaceholder
                }
            }

        tableView.bind(viewModel.isPressureAlertExpanded) { tableView, _ in
            if tableView.window != nil {
                tableView.reloadData()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindRhAlertCells() {
        guard isViewLoaded, let viewModel = viewModel  else { return }

        rhAlertHeaderCell.mutedTillLabel.bind(viewModel.relativeHumidityAlertMutedTill) { (label, date) in
            if let date = date, date > Date() {
                label.isHidden = false
                label.text = AppDateFormatter.shared.shortTimeString(from: date)
            } else {
                label.isHidden = true
            }
        }

        rhAlertHeaderCell.alertStateImageView.bind(viewModel.isRelativeHumidityAlertOn) {
            [weak self] (imageView, isOn) in
            imageView.image = isOn.bound ? self?.alertOnImage : nil
        }

        rhAlertHeaderCell.alertStateImageView.bind(viewModel.relativeHumidityAlertState) {
            [weak self] (imageView, state) in
            imageView.layer.removeAllAnimations()
            if let state = state {
                switch state {
                case .empty:
                    imageView.image = nil
                case .registered:
                    imageView.alpha = 1.0
                    imageView.image = self?.alertOnImage
                case .firing:
                    if imageView.image != self?.alertActiveImage {
                        imageView.image = self?.alertActiveImage
                        UIView.animate(withDuration: 0.5,
                                      delay: 0,
                                      options: [.repeat, .autoreverse],
                                      animations: { [weak imageView] in
                                        imageView?.alpha = 0.0
                                    })
                    }
                }
            }
        }

        rhAlertControlsCell.statusSwitch.bind(viewModel.isRelativeHumidityAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
        }

        rhAlertControlsCell.statusLabel.bind(viewModel.isRelativeHumidityAlertOn) { (label, isOn) in
            label.text = isOn.bound ? "On".localized() : "Off".localized()
        }

        rhAlertControlsCell.alertLimitSliderView.bind(viewModel.relativeHumidityLowerBound) { [weak self] (_, _) in
            self?.updateUIRhLowerBound()
            self?.updateUIRhAlertDescription()
        }

        rhAlertControlsCell.alertLimitSliderView.bind(viewModel.relativeHumidityUpperBound) { [weak self] (_, _) in
            self?.updateUIRhUpperBound()
            self?.updateUIRhAlertDescription()
        }

        rhAlertHeaderCell.titleLabel.bind(viewModel.humidityUnit) { (label, _) in
            let title = "TagSettings.AirHumidityAlert.title"
            let symbol = HumidityUnit.percent.symbol
            label.text = String(format: title.localized(), symbol)
        }

        rhAlertControlsCell.alertLimitSliderView.bind(viewModel.humidityUnit) { (slider, _) in
            let hu = HumidityUnit.percent
            slider.minValue = CGFloat(hu.alertRange.lowerBound)
            slider.maxValue = CGFloat(hu.alertRange.upperBound)
        }

        rhAlertControlsCell.setCustomDescriptionView.titleLabel.bind(viewModel.relativeHumidityAlertDescription) {
            [weak self] (label, humidityAlertDescription) in
            if humidityAlertDescription.hasText() {
                label.text = humidityAlertDescription
            } else {
                label.text = self?.alertPlaceholder
            }
        }

        tableView.bind(viewModel.isRelativeHumidityAlertExpanded) { tableView, _ in
            if tableView.window != nil {
                tableView.reloadData()
            }
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

    // swiftlint:disable:next cyclomatic_complexity
    func textField(_ textField: UITextField, shouldChangeCharactersIn
                   range: NSRange,
                   replacementString string: String) -> Bool {
        guard let text = textField.text else {
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

            guard let text = textField.text, let decimalSeparator = NSLocale.current.decimalSeparator else {
                return true
            }

            var splitText = text.components(separatedBy: decimalSeparator)
            let totalDecimalSeparators = splitText.count - 1
            let isEditingEnd = (text.count - 3) < range.lowerBound

            splitText.removeFirst()

            // Check if we will exceed 2 dp
            if
                splitText.last?.count ?? 0 > 1 && string.count != 0 &&
                    isEditingEnd
            {
                return false
            }

            // If there is already a dot we don't want to allow further dots
            if totalDecimalSeparators > 0 && string == decimalSeparator {
                return false
            }

            // Only allow numbers and decimal separator
            switch string {
            case "", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", decimalSeparator:
                return true
            default:
                return false
            }

        } else {
            return false
        }
    }
}

// MARK: - Update UI
extension TagSettingsTableViewController {
    private func updateUI() {
        updateUITemperatureAlertDescription()
        updateUITemperatureLowerBound()
        updateUITemperatureUpperBound()

        updateUIPressureAlertDescription()
        updateUIPressureLowerBound()
        updateUIPressureUpperBound()
    }
    // MARK: - updateUITemperature

    private func updateUITemperatureLowerBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel?.temperatureUnit.value else {
            let range = TemperatureUnit.celsius.alertRange
            temperatureAlertControlsCell.alertLimitSliderView.minValue = CGFloat(range.lowerBound)
            temperatureAlertControlsCell.alertLimitSliderView.selectedMinValue = CGFloat(range.lowerBound)
            return
        }
        if let lower = viewModel?.temperatureLowerBound.value?.converted(to: temperatureUnit.unitTemperature) {
            temperatureAlertControlsCell.alertLimitSliderView.selectedMinValue = CGFloat(lower.value)
        } else {
            let lower: CGFloat = CGFloat(temperatureUnit.alertRange.lowerBound)
            temperatureAlertControlsCell.alertLimitSliderView.selectedMinValue = lower
        }
    }

    private func updateUITemperatureUpperBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel?.temperatureUnit.value else {
            let range = TemperatureUnit.celsius.alertRange
            temperatureAlertControlsCell.alertLimitSliderView.maxValue = CGFloat(range.upperBound)
            temperatureAlertControlsCell.alertLimitSliderView.selectedMaxValue = CGFloat(range.upperBound)
            return
        }
        if let upper = viewModel?.temperatureUpperBound.value?.converted(to: temperatureUnit.unitTemperature) {
            temperatureAlertControlsCell.alertLimitSliderView.selectedMaxValue = CGFloat(upper.value)
        } else {
            let upper: CGFloat = CGFloat(temperatureUnit.alertRange.upperBound)
            temperatureAlertControlsCell.alertLimitSliderView.selectedMaxValue = upper
        }
    }

    private func updateUITemperatureAlertDescription() {
        guard isViewLoaded else { return }
        if let tu = viewModel?.temperatureUnit.value?.unitTemperature,
           let l = viewModel?.temperatureLowerBound.value?.converted(to: tu),
           let u = viewModel?.temperatureUpperBound.value?.converted(to: tu) {
            var format = "TagSettings.Alerts.Temperature.description".localized()
            if l.value.decimalPoint > 0 {
                let decimalPointToConsider = l.value.decimalPoint > 2 ? 2 : l.value.decimalPoint
                format = format.replacingFirstOccurrence(of: "%0.f",
                                                         with: "%0.\(decimalPointToConsider)f")
            }

            if u.value.decimalPoint > 0 {
                let decimalPointToConsider = u.value.decimalPoint > 2 ? 2 : u.value.decimalPoint
                format = format.replacingLastOccurrence(of: "%0.f",
                                                        with: "%0.\(decimalPointToConsider)f")
            }

            let message = String(format: format, l.value.round(to: 2), u.value.round(to: 2))
            temperatureAlertControlsCell.setAlertLimitDescription(with: message)
        }
    }

    // MARK: - updateRh
    private func updateUIRhLowerBound() {
        guard isViewLoaded else { return }
        let range = HumidityUnit.percent.alertRange
        if let lower = viewModel?.relativeHumidityLowerBound.value {
            rhAlertControlsCell.alertLimitSliderView.selectedMinValue = CGFloat(lower)
        } else {
            rhAlertControlsCell.alertLimitSliderView.selectedMinValue = CGFloat(range.lowerBound)
        }
    }

    private func updateUIRhUpperBound() {
        guard isViewLoaded else { return }
        let range = HumidityUnit.percent.alertRange
        if let upper = viewModel?.relativeHumidityUpperBound.value {
            rhAlertControlsCell.alertLimitSliderView.selectedMaxValue = CGFloat(upper)
        } else {
            rhAlertControlsCell.alertLimitSliderView.selectedMaxValue = CGFloat(range.upperBound)
        }
    }

    private func updateUIRhAlertDescription() {
        guard isViewLoaded else { return }
        if let l = viewModel?.relativeHumidityLowerBound.value,
           let u = viewModel?.relativeHumidityUpperBound.value {
            var format = "TagSettings.Alerts.Humidity.description".localized()
            if l.decimalPoint > 0 {
                let decimalPointToConsider = l.decimalPoint > 2 ? 2 : l.decimalPoint
                format = format.replacingFirstOccurrence(of: "%0.f", with: "%0.\(decimalPointToConsider)f")
            }

            if u.decimalPoint > 0 {
                let decimalPointToConsider = u.decimalPoint > 2 ? 2 : u.decimalPoint
                format = format.replacingLastOccurrence(of: "%0.f", with: "%0.\(decimalPointToConsider)f")
            }
            let message = String(format: format, l.round(to: 2), u.round(to: 2))
            rhAlertControlsCell.setAlertLimitDescription(with: message)
        }
    }

    // MARK: - updateUIPressure
    private func updateUIPressureLowerBound() {
        guard isViewLoaded else { return }
        guard let pu = viewModel?.pressureUnit.value else {
            let range = UnitPressure.hectopascals.alertRange
            pressureAlertControlsCell.alertLimitSliderView.minValue = CGFloat(range.lowerBound)
            pressureAlertControlsCell.alertLimitSliderView.selectedMinValue = CGFloat(range.lowerBound)
            return
        }
        if let lower = viewModel?.pressureLowerBound.value?.converted(to: pu).value {
            let l = min(
                max(lower, pu.alertRange.lowerBound),
                pu.alertRange.upperBound
            )
            pressureAlertControlsCell.alertLimitSliderView.selectedMinValue = CGFloat(l)
        } else {
            pressureAlertControlsCell.alertLimitSliderView.selectedMinValue = CGFloat(pu.alertRange.lowerBound)
        }
    }

    private func updateUIPressureUpperBound() {
        guard isViewLoaded else { return }
        guard let pu = viewModel?.pressureUnit.value else {
            let range = UnitPressure.hectopascals.alertRange
            pressureAlertControlsCell.alertLimitSliderView.maxValue =  CGFloat(range.upperBound)
            pressureAlertControlsCell.alertLimitSliderView.selectedMaxValue =  CGFloat(range.upperBound)
            return
        }
        if let upper = viewModel?.pressureUpperBound.value?.converted(to: pu).value {
            let u = max(
                min(upper, pu.alertRange.upperBound),
                pu.alertRange.lowerBound
            )
            pressureAlertControlsCell.alertLimitSliderView.selectedMaxValue = CGFloat(u)
        } else {
            pressureAlertControlsCell.alertLimitSliderView.selectedMaxValue = CGFloat(pu.alertRange.upperBound)
        }
    }

    private func updateUIPressureAlertDescription() {
        guard isViewLoaded else { return }
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
            var format = "TagSettings.Alerts.Pressure.description".localized()
            if l.decimalPoint > 0 {
                let decimalPointToConsider = l.decimalPoint > 2 ? 2 : l.decimalPoint
                format = format.replacingFirstOccurrence(of: "%0.f", with: "%0.\(decimalPointToConsider)f")
            }

            if u.decimalPoint > 0 {
                let decimalPointToConsider = u.decimalPoint > 2 ? 2 : u.decimalPoint
                format = format.replacingLastOccurrence(of: "%0.f", with: "%0.\(decimalPointToConsider)f")
            }
            let message = String(format: format, l.round(to: 2), u.round(to: 2))
            pressureAlertControlsCell.setAlertLimitDescription(with: message)
        }
    }
}

// MARK: - SET CUSTOM ALERT RANGE POPUP
extension TagSettingsTableViewController {
    private func showTemparatureAlertSetPopup(sender: TagSettingsAlertDetailsCell) {
        let title = "TagSettings.Alert.SetTemperature.title".localized()
        let (minimumRange, maximumRange) = temperatureAlertRange()
        let (minimumValue, maximumValue) = temperatureValue()
        showSensorCustomAlertRangeDialog(title: title,
                                         minimumBound: minimumRange,
                                         maximumBound: maximumRange,
                                         currentLowerBound: minimumValue,
                                         currentUpperBound: maximumValue,
                                         sender: sender)
    }

    private func showHumidityAlertSetDialog(sender: TagSettingsAlertDetailsCell) {
        let title = "TagSettings.Alert.SetHumidity.title".localized()

        let (minimumRange, maximumRange) = humidityAlertRange()
        let (minimumValue, maximumValue) = humidityValue()
        showSensorCustomAlertRangeDialog(title: title,
                                         minimumBound: minimumRange,
                                         maximumBound: maximumRange,
                                         currentLowerBound: minimumValue,
                                         currentUpperBound: maximumValue,
                                         sender: sender)
    }

    private func showPressureAlertSetDialog(sender: TagSettingsAlertDetailsCell) {
        let title = "TagSettings.Alert.SetPressure.title".localized()

        let (minimumRange, maximumRange) = pressureAlertRange()
        let (minimumValue, maximumValue) = pressureValue()
        showSensorCustomAlertRangeDialog(title: title,
                                         minimumBound: minimumRange,
                                         maximumBound: maximumRange,
                                         currentLowerBound: minimumValue,
                                         currentUpperBound: maximumValue,
                                         sender: sender)
    }

    private func temperatureAlertRange() -> (minimum: Double, maximum: Double) {
        let temperatureUnit = viewModel?.temperatureUnit.value ?? .celsius
        return (minimum: temperatureUnit.alertRange.lowerBound,
                maximum: temperatureUnit.alertRange.upperBound)
    }

    private func temperatureValue() -> (minimum: Double?, maximum: Double?) {
        if let unit = viewModel?.temperatureUnit.value?.unitTemperature,
           let l = viewModel?.temperatureLowerBound.value?.converted(to: unit),
           let u = viewModel?.temperatureUpperBound.value?.converted(to: unit) {
            return (minimum: l.value,
                    maximum: u.value)
        } else {
            return (minimum: nil,
                    maximum: nil)
        }
    }

    private func humidityAlertRange() -> (minimum: Double, maximum: Double) {
        let range = HumidityUnit.percent.alertRange
        return (minimum: range.lowerBound, maximum: range.upperBound)
    }

    private func humidityValue() -> (minimum: Double?, maximum: Double?) {
        if let l = viewModel?.relativeHumidityLowerBound.value,
           let u = viewModel?.relativeHumidityUpperBound.value {
            return (minimum: l, maximum: u)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    private func pressureAlertRange() -> (minimum: Double, maximum: Double) {
        let pressureUnit = viewModel?.pressureUnit.value ?? .hectopascals
        return (minimum: pressureUnit.alertRange.lowerBound,
                maximum: pressureUnit.alertRange.upperBound)
    }

    private func pressureValue() -> (minimum: Double?, maximum: Double?) {
        let (minimumRange, maximumRange) = pressureAlertRange()
        if let pressureUnit = viewModel?.pressureUnit.value,
           let lower = viewModel?.pressureLowerBound.value?.converted(to: pressureUnit).value,
           let upper = viewModel?.pressureUpperBound.value?.converted(to: pressureUnit).value {
            let l = min(
                max(lower, minimumRange),
                maximumRange
            )
            let u = max(
                min(upper, maximumRange),
                minimumRange
            )
            return (minimum: l, maximum: u)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }
}

// swiftlint:enable file_length
