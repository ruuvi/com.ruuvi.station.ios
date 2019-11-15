import UIKit
import RangeSeekSlider

enum TagSettingsTableSection: Int {
    case image = 0
    case name = 1
    case alerts = 2
    case calibration = 3
    case moreInfo = 4
    
    static func showAlerts(for viewModel: TagSettingsViewModel?) -> Bool {
        return viewModel?.isConnectable.value ?? false
    }
    
    static func section(for index: Int) -> TagSettingsTableSection {
        return TagSettingsTableSection(rawValue: index) ?? .name
    }
}

class TagSettingsTableViewController: UITableViewController {
    var output: TagSettingsViewOutput!
    
    @IBOutlet weak var temperatureAlertCell: UITableViewCell!
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
    
    @IBOutlet weak var temperatureAlertSwitch: UISwitch!
    @IBOutlet weak var temperatureAlertTitleLabel: UILabel!
    @IBOutlet weak var temperatureAlertDescriptionLabel: UILabel!
    @IBOutlet weak var temperatureAlertSlider: RURangeSeekSlider!
    
    var viewModel: TagSettingsViewModel? { didSet { bindTagSettingsViewModel() } }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
    
    private let moreInfoSectionHeaderReuseIdentifier = "TagSettingsMoreInfoHeaderFooterView"
    
    
    
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
        removeThisRuuviTagButton.setTitle("TagSettings.removeThisRuuviTagButton.text".localized(), for: .normal)
        
        if let tu = viewModel?.temperatureUnit.value {
            switch tu {
            case .celsius:
                temperatureAlertTitleLabel.text = "TagSettings.temperatureAlertTitleLabel.text".localized() + " " + "°C".localized()
            case .fahrenheit:
                temperatureAlertTitleLabel.text = "TagSettings.temperatureAlertTitleLabel.text".localized() + " " + "°F".localized()
            case .kelvin:
                temperatureAlertTitleLabel.text = "TagSettings.temperatureAlertTitleLabel.text".localized() + " " + "K".localized()
            }
        } else {
            temperatureAlertTitleLabel.text = "N/A".localized()
        }
        
        updateUITemperatureAlertDescription()
        tableView.reloadData()
    }
    
    func apply(theme: Theme) {
        
    }
    
    func showTagRemovalConfirmationDialog() {
        let controller = UIAlertController(title: "TagSettings.confirmTagRemovalDialog.title".localized(), message: "TagSettings.confirmTagRemovalDialog.message".localized(), preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(), style: .destructive, handler: { [weak self] _ in
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
        controller.addAction(UIAlertAction(title: "TagSettings.UpdateFirmware.Alert.Buttons.LearnMore.title".localized(), style: .default, handler: { [weak self] _ in
            self?.output.viewDidAskToLearnMoreAboutFirmwareUpdate()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
    
    func showHumidityIsClippedDialog() {
        let title = "TagSettings.HumidityIsClipped.Alert.title".localized()
        let message = "TagSettings.HumidityIsClipped.Alert.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "TagSettings.HumidityIsClipped.Alert.Fix.button".localized(), style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidAskToFixHumidityAdjustment()
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
    
    @IBAction func temperatureAlertSwitchValueChanged(_ sender: Any) {
        viewModel?.isTemperatureAlertOn.value = temperatureAlertSwitch.isOn
    }
}

// MARK: - RangeSeekSliderDelegate
extension TagSettingsTableViewController: RangeSeekSliderDelegate {
    func rangeSeekSlider(_ slider: RangeSeekSlider, didChange minValue: CGFloat, maxValue: CGFloat) {
        if slider === temperatureAlertSlider {
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
        case .alerts:
            return TagSettingsTableSection.showAlerts(for: viewModel) ? "TagSettings.SectionHeader.Alerts.title".localized() : nil
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
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: moreInfoSectionHeaderReuseIdentifier) as! TagSettingsMoreInfoHeaderFooterView
            header.delegate = self
            header.noValuesView.isHidden = viewModel?.version.value == 5
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
            return TagSettingsTableSection.showAlerts(for: viewModel) ? super.tableView(tableView, heightForHeaderInSection: section) : .leastNormalMagnitude
        default:
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let s = TagSettingsTableSection.section(for: section)
        switch s {
        case .alerts:
            return TagSettingsTableSection.showAlerts(for: viewModel) ? super.tableView(tableView, heightForHeaderInSection: section) : .leastNormalMagnitude
        default:
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let s = TagSettingsTableSection.section(for: section)
        switch s {
        case .alerts:
            return TagSettingsTableSection.showAlerts(for: viewModel) ? super.tableView(tableView, numberOfRowsInSection: section) : 0
        default:
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if viewModel?.isConnectable.value ?? false {
            switch cell {
            case temperatureAlertCell:
                return 144
            default:
                return 44
            }
        } else {
            switch cell {
            case temperatureAlertCell:
                return 0
            default:
                return 44
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

// MARK: - TagSettingsMoreInfoHeaderFooterViewDelegate
extension TagSettingsTableViewController: TagSettingsMoreInfoHeaderFooterViewDelegate {
    func tagSettingsMoreInfo(headerView: TagSettingsMoreInfoHeaderFooterView, didTapOnInfo button: UIButton) {
        output.viewDidTapOnNoValuesView()
    }
}

// MARK: - View configuration
extension TagSettingsTableViewController {
    private func configureViews() {
        let nib = UINib(nibName: "TagSettingsMoreInfoHeaderFooterView", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: moreInfoSectionHeaderReuseIdentifier)
        temperatureAlertSlider.delegate = self
    }
}

// MARK: - Bindings
extension TagSettingsTableViewController {
    private func bindViewModels() {
        bindTagSettingsViewModel()
    }
    private func bindTagSettingsViewModel() {
        if isViewLoaded, let viewModel = viewModel {
            
            tableView.bind(viewModel.version) { (tableView, version) in
                tableView.reloadData()
            }
            
            backgroundImageView.bind(viewModel.background) { $0.image = $1 }
            tagNameTextField.bind(viewModel.name) { $0.text = $1 }
            
            let humidity = viewModel.relativeHumidity
            let humidityOffset = viewModel.humidityOffset
            let humidityCell = calibrationHumidityCell
            let humidityTrailing = humidityLabelTrailing
            
            let humidityBlock: ((UILabel,Double?) -> Void) = { [weak humidity, weak humidityOffset, weak humidityCell, weak humidityTrailing] label, _ in
                if let humidity = humidity?.value, let humidityOffset = humidityOffset?.value {
                    if humidityOffset > 0 {
                        let shownHumidity = humidity + humidityOffset
                        if shownHumidity > 100.0 {
                            label.text = "\(String(format: "%.2f", humidity))" + " → " + "\(String(format: "%.2f", 100.0))"
                            humidityCell?.accessoryType = .detailButton
                            humidityTrailing?.constant = 0
                        } else {
                            label.text = "\(String(format: "%.2f", humidity))" + " → " + "\(String(format: "%.2f", shownHumidity))"
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
            
            uuidValueLabel.bind(viewModel.uuid) { label, uuid in
                if let uuid = uuid {
                    label.text = uuid
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }
            
            macAddressValueLabel.bind(viewModel.mac) { label, mac in
                if let mac = mac {
                    label.text = mac
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }
            
            voltageValueLabel.bind(viewModel.voltage) { label, voltage in
                if let voltage = voltage {
                    label.text = String(format: "%.3f", voltage) + " " + "V".localized()
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }
            
            accelerationXValueLabel.bind(viewModel.accelerationX) { label, accelerationX in
                if let accelerationX = accelerationX {
                    label.text = String(format: "%.3f", accelerationX) + " " + "g".localized()
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }
            
            accelerationYValueLabel.bind(viewModel.accelerationY) { label, accelerationY in
                if let accelerationY = accelerationY {
                    label.text = String(format: "%.3f", accelerationY) + " " + "g".localized()
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }
            
            accelerationZValueLabel.bind(viewModel.accelerationZ) { label, accelerationZ in
                if let accelerationZ = accelerationZ {
                    label.text = String(format: "%.3f", accelerationZ) + " " + "g".localized()
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }
            
            dataFormatValueLabel.bind(viewModel.version) { (label, version) in
                if let version = version {
                    label.text = "\(version)"
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }

            mcValueLabel.bind(viewModel.movementCounter) { (label, mc) in
                if let mc = mc {
                    label.text = "\(mc)"
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }
            
            msnValueLabel.bind(viewModel.measurementSequenceNumber) { (label, msn) in
                if let msn = msn {
                    label.text = "\(msn)"
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }
            
            txPowerValueLabel.bind(viewModel.txPower) { (label, txPower) in
                if let txPower = txPower {
                    label.text = "\(txPower)" + " " + "dBm".localized()
                } else {
                    label.text = "TagSettings.EmptyValue.sign".localized()
                }
            }
            
            tableView.bind(viewModel.isConnectable) { (tableView, isConnectable) in
                tableView.reloadData()
            }
            temperatureAlertSwitch.bind(viewModel.isTemperatureAlertOn) { (view, isOn) in
                view.isOn = isOn.bound
            }
            temperatureAlertSlider.bind(viewModel.isTemperatureAlertOn) { (slider, isOn) in
                slider.isEnabled = isOn.bound
            }
            
            temperatureAlertSlider.bind(viewModel.celsiusLowerBound) { [weak self] (slider, lower) in
                self?.updateUICelsiusLowerBound()
                self?.updateUITemperatureAlertDescription()
            }
            temperatureAlertSlider.bind(viewModel.celsiusUpperBound) { [weak self] (slider, upper) in
                self?.updateUICelsiusUpperBound()
                self?.updateUITemperatureAlertDescription()
            }
            
            temperatureAlertTitleLabel.bind(viewModel.temperatureUnit) { (label, temperatureUnit) in
                if let tu = temperatureUnit {
                    switch tu {
                    case .celsius:
                        label.text = "TagSettings.temperatureAlertTitleLabel.text".localized() + " " + "°C".localized()
                    case .fahrenheit:
                        label.text = "TagSettings.temperatureAlertTitleLabel.text".localized() + " " + "°F".localized()
                    case .kelvin:
                        label.text = "TagSettings.temperatureAlertTitleLabel.text".localized() + " "  + "K".localized()
                    }
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            temperatureAlertSlider.bind(viewModel.temperatureUnit) { (slider, temperatureUnit) in
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
            
            temperatureAlertDescriptionLabel.bind(viewModel.isTemperatureAlertOn) { [weak self] (label, isOn) in
                self?.updateUITemperatureAlertDescription()
            }
            
            temperatureAlertSwitch.bind(viewModel.isConnected) { (view, isConnected) in
                view.isEnabled = isConnected.bound
                view.onTintColor = isConnected.bound ? UISwitch.appearance().onTintColor : .gray
            }
            
            temperatureAlertSlider.bind(viewModel.isConnected) { (slider, isConnected) in
                slider.isEnabled = isConnected.bound
            }
        }
    }
}

// MARK: - Update UI
extension TagSettingsTableViewController {
    private func updateUI() {
        updateUITemperatureAlertDescription()
        updateUICelsiusLowerBound()
        updateUICelsiusUpperBound()
    }
    
    private func updateUICelsiusLowerBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel?.temperatureUnit.value {
                if let lower = viewModel?.celsiusLowerBound.value {
                    switch temperatureUnit {
                    case .celsius:
                        temperatureAlertSlider.selectedMinValue = CGFloat(lower)
                    case .fahrenheit:
                        temperatureAlertSlider.selectedMinValue = CGFloat(lower.fahrenheit)
                    case .kelvin:
                        temperatureAlertSlider.selectedMinValue = CGFloat(lower.kelvin)
                    }
                } else {
                    temperatureAlertSlider.selectedMinValue = -40
                }
            } else {
                temperatureAlertSlider.minValue = -40
                temperatureAlertSlider.selectedMinValue = -40
            }
        }
    }
    
    private func updateUICelsiusUpperBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel?.temperatureUnit.value {
                if let upper = viewModel?.celsiusUpperBound.value {
                    switch temperatureUnit {
                    case .celsius:
                        temperatureAlertSlider.selectedMaxValue = CGFloat(upper)
                    case .fahrenheit:
                        temperatureAlertSlider.selectedMaxValue = CGFloat(upper.fahrenheit)
                    case .kelvin:
                        temperatureAlertSlider.selectedMaxValue = CGFloat(upper.kelvin)
                    }
                } else {
                    temperatureAlertSlider.selectedMaxValue = 85
                }
            } else {
                temperatureAlertSlider.maxValue = 85
                temperatureAlertSlider.selectedMaxValue = 85
            }
        }
    }
    
    private func updateUITemperatureAlertDescription() {
        if isViewLoaded {
            if let isTemperatureAlertOn = viewModel?.isTemperatureAlertOn.value, isTemperatureAlertOn {
                if let l = viewModel?.celsiusLowerBound.value, let u = viewModel?.celsiusUpperBound.value, let tu = viewModel?.temperatureUnit.value {
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
                    temperatureAlertDescriptionLabel.text = String(format: "TagSettings.Alerts.Temperature.description".localized(), la, ua)
                } else {
                    temperatureAlertDescriptionLabel.text = "TagSettings.Alerts.Off".localized()
                }
            } else {
                temperatureAlertDescriptionLabel.text = "TagSettings.Alerts.Off".localized()
            }
        }
    }
}
