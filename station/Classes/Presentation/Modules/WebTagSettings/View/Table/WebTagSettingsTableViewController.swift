// swiftlint:disable file_length
import UIKit

private enum WebTagSettingsTableSection: Int {
    case name = 0
    case alerts = 1
    case moreInfo = 2

    static func section(for sectionIndex: Int) -> WebTagSettingsTableSection {
        return WebTagSettingsTableSection(rawValue: sectionIndex) ?? .name
    }
}

class WebTagSettingsTableViewController: UITableViewController {
    var output: WebTagSettingsViewOutput!

    @IBOutlet weak var pressureAlertHeaderCell: WebTagSettingsAlertHeaderCell!
    @IBOutlet weak var pressureAlertControlsCell: WebTagSettingsAlertControlsCell!
    @IBOutlet weak var dewPointAlertHeaderCell: WebTagSettingsAlertHeaderCell!
    @IBOutlet weak var dewPointAlertControlsCell: WebTagSettingsAlertControlsCell!
    @IBOutlet weak var humidityAlertHeaderCell: WebTagSettingsAlertHeaderCell!
    @IBOutlet weak var humidityAlertControlsCell: WebTagSettingsAlertControlsCell!
    @IBOutlet weak var temperatureAlertHeaderCell: WebTagSettingsAlertHeaderCell!
    @IBOutlet weak var temperatureAlertControlsCell: WebTagSettingsAlertControlsCell!
    @IBOutlet weak var tagNameTextField: UITextField!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tagNameCell: UITableViewCell!
    @IBOutlet weak var locationCell: UITableViewCell!
    @IBOutlet weak var locationValueLabel: UILabel!
    @IBOutlet weak var clearLocationButton: UIButton!
    @IBOutlet weak var clearLocationButtonWidth: NSLayoutConstraint!
    @IBOutlet weak var backgroundImageLabel: UILabel!
    @IBOutlet weak var tagNameTitleLabel: UILabel!
    @IBOutlet weak var removeThisWebTagButton: UIButton!
    @IBOutlet weak var locationTitleLabel: UILabel!

    var isNameChangedEnabled: Bool = true {
        didSet {
            updateUIIsNamaChangeEnabled()
        }
    }

    var viewModel = WebTagSettingsViewModel() {
        didSet {
            bindViewModel()
        }
    }

    private let alertsSectionHeaderReuseIdentifier = "WebTagSettingsAlertsHeaderFooterView"
    private let alertOffString = "WebTagSettings.Alerts.Off"
}

// MARK: - WebTagSettingsViewInput
extension WebTagSettingsTableViewController: WebTagSettingsViewInput {
    func localize() {
        navigationItem.title = "WebTagSettings.navigationItem.title".localized()
        backgroundImageLabel.text = "WebTagSettings.Label.BackgroundImage.text".localized()
        tagNameTitleLabel.text = "WebTagSettings.Label.TagName.text".localized()
        locationTitleLabel.text = "WebTagSettings.Label.Location.text".localized()

        removeThisWebTagButton.setTitle("WebTagSettings.Button.Remove.title".localized(), for: .normal)

        let alertPlaceholder = "TagSettings.Alert.CustomDescription.placeholder".localized()
        temperatureAlertControlsCell.textField.placeholder = alertPlaceholder
        humidityAlertControlsCell.textField.placeholder = alertPlaceholder
        dewPointAlertControlsCell.textField.placeholder = alertPlaceholder
        pressureAlertControlsCell.textField.placeholder = alertPlaceholder

        tableView.reloadData()
    }

    func showTagRemovalConfirmationDialog() {
        let title = "WebTagSettings.confirmTagRemovalDialog.title".localized()
        let message = "WebTagSettings.confirmTagRemovalDialog.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(),
                                           style: .destructive,
                                           handler: { [weak self] _ in
            self?.output.viewDidConfirmTagRemoval()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showClearLocationConfirmationDialog() {
        let title = "WebTagSettings.confirmClearLocationDialog.title".localized()
        let message = "WebTagSettings.confirmClearLocationDialog.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(),
                                           style: .destructive,
                                           handler: { [weak self] _ in
            self?.output.viewDidConfirmToClearLocation()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showBothNoPNPermissionAndNoLocationPermission() {
        let message
            = "WebTagSettings.AlertsAreDisabled.Dialog.BothNoPNPermissionAndNoLocationPermission.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionTitle = "WebTagSettings.AlertsAreDisabled.Dialog.Settings.title".localized()
        controller.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidAskToOpenSettings()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

// MARK: - IBActions
extension WebTagSettingsTableViewController {
    @IBAction func dismissBarButtonItemAction(_ sender: Any) {
        output.viewDidAskToDismiss()
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

    @IBAction func removeThisWebTagButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToRemoveWebTag()
    }

    @IBAction func clearLocationButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToClearLocation()
    }
}

// MARK: - View lifecycle
extension WebTagSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        setupLocalization()
        bindViewModel()
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
}

// MARK: - UITableViewDelegate
extension WebTagSettingsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        switch cell {
        case tagNameCell:
            tagNameTextField.becomeFirstResponder()
        case locationCell:
            output.viewDidAskToSelectLocation()
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        let headerHeight: CGFloat = 66
        let controlsHeight: CGFloat = 148
        let hu = viewModel.humidityUnit.value
        switch cell {
        case temperatureAlertHeaderCell,
             pressureAlertHeaderCell:
            return headerHeight
        case temperatureAlertControlsCell:
            return (viewModel.isTemperatureAlertOn.value ?? false) ? controlsHeight : 0
        case humidityAlertHeaderCell:
            return (hu != .dew) ? headerHeight : 0
        case humidityAlertControlsCell:
            return ((hu != .dew) && viewModel.isHumidityAlertOn.value ?? false) ? controlsHeight : 0
        case dewPointAlertHeaderCell:
            return (hu == .dew) ? headerHeight : 0
        case dewPointAlertControlsCell:
            return ((hu == .dew)  && viewModel.isDewPointAlertOn.value ?? false) ? controlsHeight : 0
        case pressureAlertControlsCell:
            return (viewModel.isPressureAlertOn.value ?? false) ? controlsHeight : 0
        default:
            return 44
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = WebTagSettingsTableSection.section(for: section)
        switch section {
        case .name:
            return "WebTagSettings.SectionHeader.Name.title".localized()
        case .moreInfo:
            return "WebTagSettings.SectionHeader.MoreInfo.title".localized()
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = WebTagSettingsTableSection.section(for: section)
        switch section {
        case .alerts:
            // swiftlint:disable force_cast
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: alertsSectionHeaderReuseIdentifier)
                as! WebTagSettingsAlertsHeaderFooterView
            // swiftlint:enable force_cast
            header.delegate = self
            let isCurrentLocation = viewModel.location.value == nil
            let isLocationAlwaysAuthorized = viewModel.isLocationAuthorizedAlways.value ?? false
            let isPushNotificationsEnabled = viewModel.isPushNotificationsEnabled.value ?? false
            let isVisible = !isPushNotificationsEnabled || (isCurrentLocation && !isLocationAlwaysAuthorized)
            header.disabledView.isHidden = !isVisible
            return header
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let s = WebTagSettingsTableSection.section(for: section)
        switch s {
        case .alerts:
            return 44
        default:
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }
}

// MARK: - WebTagSettingsAlertsHeaderFooterViewDelegate
extension WebTagSettingsTableViewController: WebTagSettingsAlertsHeaderFooterViewDelegate {
    func webTagSettingsAlerts(headerView: WebTagSettingsAlertsHeaderFooterView, didTapOnDisabled button: UIButton) {
        output.viewDidTapOnAlertsDisabledView()
    }
}

// MARK: - UITextFieldDelegate
extension WebTagSettingsTableViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: - View configuration
extension WebTagSettingsTableViewController {
    private func configureViews() {
        let alertsSectionNib = UINib(nibName: "WebTagSettingsAlertsHeaderFooterView", bundle: nil)
        tableView.register(alertsSectionNib, forHeaderFooterViewReuseIdentifier: alertsSectionHeaderReuseIdentifier)
        temperatureAlertHeaderCell.delegate = self
        temperatureAlertControlsCell.delegate = self
        humidityAlertHeaderCell.delegate = self
        humidityAlertControlsCell.delegate = self
        dewPointAlertHeaderCell.delegate = self
        dewPointAlertControlsCell.delegate = self
        pressureAlertHeaderCell.delegate = self
        pressureAlertControlsCell.delegate = self

        configureMinMaxForSliders()
    }

    private func configureMinMaxForSliders() {
        let tu = viewModel.temperatureUnit.value ?? .celsius
        temperatureAlertControlsCell.slider.minValue = CGFloat(tu.alertRange.lowerBound)
        temperatureAlertControlsCell.slider.maxValue = CGFloat(tu.alertRange.upperBound)
        dewPointAlertControlsCell.slider.minValue = CGFloat(tu.alertRange.lowerBound)
        dewPointAlertControlsCell.slider.maxValue = CGFloat(tu.alertRange.upperBound)

        let hu = viewModel.humidityUnit.value ?? .percent
        humidityAlertControlsCell.slider.minValue = CGFloat(hu.alertRange.lowerBound)
        humidityAlertControlsCell.slider.maxValue = CGFloat(hu.alertRange.upperBound)

        let p = viewModel.pressureUnit.value ?? .hectopascals
        pressureAlertControlsCell.slider.minValue = CGFloat(p.alertRange.lowerBound)
        pressureAlertControlsCell.slider.maxValue = CGFloat(p.alertRange.upperBound)
    }
}

// MARK: - Update UI
extension WebTagSettingsTableViewController {
    private func updateUI() {
        updateUIIsNamaChangeEnabled()
    }

    private func updateUIIsNamaChangeEnabled() {
        if isViewLoaded {
            tagNameTextField.isEnabled = isNameChangedEnabled
        }
    }
    // MARK: - updateUITemperature

    private func updateUITemperatureLowerBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel.temperatureUnit.value else {
            let range = TemperatureUnit.celsius.alertRange
            temperatureAlertControlsCell.slider.minValue = CGFloat(range.lowerBound)
            temperatureAlertControlsCell.slider.selectedMinValue = CGFloat(range.lowerBound)
            return
        }
        if let lower = viewModel.temperatureLowerBound.value?.converted(to: temperatureUnit.unitTemperature) {
            temperatureAlertControlsCell.slider.selectedMinValue = CGFloat(lower.value)
        } else {
            let lower: CGFloat = CGFloat(temperatureUnit.alertRange.lowerBound)
            temperatureAlertControlsCell.slider.selectedMinValue = lower
        }
    }

    private func updateUITemperatureUpperBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel.temperatureUnit.value else {
            let range = TemperatureUnit.celsius.alertRange
            temperatureAlertControlsCell.slider.maxValue = CGFloat(range.upperBound)
            temperatureAlertControlsCell.slider.selectedMaxValue = CGFloat(range.upperBound)
            return
        }
        if let upper = viewModel.temperatureUpperBound.value?.converted(to: temperatureUnit.unitTemperature) {
            temperatureAlertControlsCell.slider.selectedMaxValue = CGFloat(upper.value)
        } else {
            let upper: CGFloat = CGFloat(temperatureUnit.alertRange.upperBound)
            temperatureAlertControlsCell.slider.selectedMaxValue = upper
        }
    }

    private func updateUITemperatureAlertDescription() {
        guard isViewLoaded else { return }
        guard viewModel.isTemperatureAlertOn.value == true else {
            temperatureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            return
        }
        if let tu = viewModel.temperatureUnit.value?.unitTemperature,
           let l = viewModel.temperatureLowerBound.value?.converted(to: tu),
           let u = viewModel.temperatureUpperBound.value?.converted(to: tu) {
            let format = "WebTagSettings.Alerts.Temperature.description".localized()
            temperatureAlertHeaderCell.descriptionLabel.text = String(format: format, l.value, u.value)
        } else {
            temperatureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }

    // MARK: - updateUIHumidity

    private func updateUIHumidityLowerBound() {
        guard isViewLoaded else { return }
        guard let hu = viewModel.humidityUnit.value else {
            let range = HumidityUnit.gm3.alertRange
            humidityAlertControlsCell.slider.minValue = CGFloat(range.lowerBound)
            humidityAlertControlsCell.slider.selectedMinValue = CGFloat(range.lowerBound)
            return
        }
        if let lower = viewModel.humidityLowerBound.value {
            switch hu {
            case .gm3:
                let lowerAbsolute: Double = max(lower.converted(to: .absolute).value, hu.alertRange.lowerBound)
                humidityAlertControlsCell.slider.selectedMinValue = CGFloat(lowerAbsolute)
            default:
                if let t = viewModel.temperature.value {
                    let minValue: Double = lower.converted(to: .relative(temperature: t)).value
                    let lowerRelative: Double = min(
                        max(minValue * 100, HumidityUnit.percent.alertRange.lowerBound),
                        HumidityUnit.percent.alertRange.upperBound
                    )
                    humidityAlertControlsCell.slider.selectedMinValue = CGFloat(lowerRelative)
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
        guard let hu = viewModel.humidityUnit.value else {
            let range = HumidityUnit.gm3.alertRange
            humidityAlertControlsCell.slider.maxValue = CGFloat(range.upperBound)
            humidityAlertControlsCell.slider.selectedMaxValue = CGFloat(range.upperBound)
            return
        }
        if let upper = viewModel.humidityUpperBound.value {
            switch hu {
            case .gm3:
                let upperAbsolute: Double = min(upper.converted(to: .absolute).value, hu.alertRange.upperBound)
                humidityAlertControlsCell.slider.selectedMaxValue = CGFloat(upperAbsolute)
            default:
                if let t = viewModel.temperature.value {
                    let maxValue: Double = upper.converted(to: .relative(temperature: t)).value
                    let upperRelative: Double = min(maxValue * 100, HumidityUnit.percent.alertRange.upperBound)
                    humidityAlertControlsCell.slider.selectedMaxValue = CGFloat(upperRelative)
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
        guard let isHumidityAlertOn = viewModel.isHumidityAlertOn.value,
              isHumidityAlertOn else {
            humidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            return
        }
        if let hu = viewModel.humidityUnit.value,
           let l = viewModel.humidityLowerBound.value,
           let u = viewModel.humidityUpperBound.value {
            let format = "WebTagSettings.Alerts.Humidity.description".localized()
            let description: String
            if hu == .gm3 {
                let la: Double = max(l.converted(to: .absolute).value, hu.alertRange.lowerBound)
                let ua: Double = min(u.converted(to: .absolute).value, hu.alertRange.upperBound)
                description = String(format: format, la, ua)
            } else {
                if let t = viewModel.temperature.value {
                    let lv: Double = l.converted(to: .relative(temperature: t)).value * 100.0
                    let lr: Double = min(
                        max(lv, HumidityUnit.percent.alertRange.lowerBound),
                        HumidityUnit.percent.alertRange.upperBound
                    )
                    let ua: Double = u.converted(to: .relative(temperature: t)).value * 100.0
                    let ur: Double = max(
                        min(ua, HumidityUnit.percent.alertRange.upperBound),
                        HumidityUnit.percent.alertRange.lowerBound
                    )
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
        guard let pu = viewModel.pressureUnit.value else {
            let range = UnitPressure.hectopascals.alertRange
            pressureAlertControlsCell.slider.minValue = CGFloat(range.lowerBound)
            pressureAlertControlsCell.slider.selectedMinValue = CGFloat(range.lowerBound)
            return
        }
        if let lower = viewModel.pressureLowerBound.value?.converted(to: pu).value {
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
        guard let pu = viewModel.pressureUnit.value else {
            let range = UnitPressure.hectopascals.alertRange
            pressureAlertControlsCell.slider.maxValue =  CGFloat(range.upperBound)
            pressureAlertControlsCell.slider.selectedMaxValue =  CGFloat(range.upperBound)
            return
        }
        if let upper = viewModel.pressureUpperBound.value?.converted(to: pu).value {
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
        guard let isPressureAlertOn = viewModel.isPressureAlertOn.value,
              isPressureAlertOn else {
            pressureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            return
        }
        if let pu = viewModel.pressureUnit.value,
           let lower = viewModel.pressureLowerBound.value?.converted(to: pu).value,
           let upper = viewModel.pressureUpperBound.value?.converted(to: pu).value {
            let l = min(
                max(lower, pu.alertRange.lowerBound),
                pu.alertRange.upperBound
            )
            let u = max(
                min(upper, pu.alertRange.upperBound),
                pu.alertRange.lowerBound
            )
            let format = "WebTagSettings.Alerts.Pressure.description".localized()
            pressureAlertHeaderCell.descriptionLabel.text = String(format: format, l, u)
        } else {
            pressureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }

    // MARK: updateUIDewPoint

    private func updateUIDewPointCelsiusLowerBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel.temperatureUnit.value else {
            let range = TemperatureUnit.celsius.alertRange
            dewPointAlertControlsCell.slider.minValue = CGFloat(range.lowerBound)
            dewPointAlertControlsCell.slider.selectedMinValue = CGFloat(range.lowerBound)
            return
        }
        if let lower = viewModel.dewPointLowerBound.value?.converted(to: temperatureUnit.unitTemperature) {
            dewPointAlertControlsCell.slider.selectedMinValue = CGFloat(lower.value)
        } else {
            let lower: CGFloat = CGFloat(temperatureUnit.alertRange.lowerBound)
            dewPointAlertControlsCell.slider.selectedMinValue = lower
        }
    }

    private func updateUIDewPointCelsiusUpperBound() {
        guard isViewLoaded else { return }
        guard let temperatureUnit = viewModel.temperatureUnit.value else {
            dewPointAlertControlsCell.slider.maxValue = CGFloat(TemperatureUnit.celsius.alertRange.upperBound)
            dewPointAlertControlsCell.slider.selectedMaxValue = CGFloat(TemperatureUnit.celsius.alertRange.upperBound)
            return
        }
        if let upper = viewModel.dewPointUpperBound.value?.converted(to: temperatureUnit.unitTemperature) {
            dewPointAlertControlsCell.slider.selectedMaxValue = CGFloat(upper.value)
        } else {
            let upper: CGFloat = CGFloat(temperatureUnit.alertRange.upperBound)
            dewPointAlertControlsCell.slider.selectedMaxValue = upper
        }
    }

    private func updateUIDewPointAlertDescription() {
        guard isViewLoaded else { return }
        guard viewModel.isDewPointAlertOn.value == true else {
            dewPointAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            return
        }
        if let tu = viewModel.temperatureUnit.value?.unitTemperature,
           let l = viewModel.dewPointLowerBound.value?.converted(to: tu),
           let u = viewModel.dewPointUpperBound.value?.converted(to: tu) {
            let format = "WebTagSettings.Alerts.DewPoint.description".localized()
            dewPointAlertHeaderCell.descriptionLabel.text = String(format: format, l.value, u.value)
        } else {
            dewPointAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
        }
    }
}

// MARK: - WebTagSettingsAlertHeaderCellDelegate
extension WebTagSettingsTableViewController: WebTagSettingsAlertHeaderCellDelegate {
    func webTagSettingsAlertHeader(cell: WebTagSettingsAlertHeaderCell, didToggle isOn: Bool) {
        switch cell {
        case temperatureAlertHeaderCell:
            viewModel.isTemperatureAlertOn.value = isOn
        case humidityAlertHeaderCell:
            viewModel.isHumidityAlertOn.value = isOn
        case dewPointAlertHeaderCell:
            viewModel.isDewPointAlertOn.value = isOn
        case pressureAlertHeaderCell:
            viewModel.isPressureAlertOn.value = isOn
        default:
            break
        }
    }
}

// MARK: - WebTagSettingsAlertControlsCellDelegate
extension WebTagSettingsTableViewController: WebTagSettingsAlertControlsCellDelegate {
    func webTagSettingsAlertControls(cell: WebTagSettingsAlertControlsCell, didEnter description: String?) {
        switch cell {
        case temperatureAlertControlsCell:
            viewModel.temperatureAlertDescription.value = description
        case humidityAlertControlsCell:
            viewModel.humidityAlertDescription.value = description
        case dewPointAlertControlsCell:
            viewModel.dewPointAlertDescription.value = description
        case pressureAlertControlsCell:
            viewModel.pressureAlertDescription.value = description
        default:
            break
        }
    }

    func webTagSettingsAlertControls(cell: WebTagSettingsAlertControlsCell,
                                     didSlideTo minValue: CGFloat,
                                     maxValue: CGFloat) {
        switch cell {
        case temperatureAlertControlsCell:
            if let tu = viewModel.temperatureUnit.value {
                viewModel.temperatureLowerBound.value = Temperature(Double(minValue), unit: tu.unitTemperature)
                viewModel.temperatureUpperBound.value = Temperature(Double(maxValue), unit: tu.unitTemperature)
            }
        case humidityAlertControlsCell:
            if let hu = viewModel.humidityUnit.value,
               let t = viewModel.temperature.value {
                switch hu {
                case .gm3:
                    viewModel.humidityLowerBound.value = Humidity(value: Double(minValue), unit: .absolute)
                    viewModel.humidityUpperBound.value = Humidity(value: Double(maxValue), unit: .absolute)
                default:
                    viewModel.humidityLowerBound.value = Humidity(value: Double(minValue / 100.0),
                                                                  unit: .relative(temperature: t))
                    viewModel.humidityUpperBound.value = Humidity(value: Double(maxValue / 100.0),
                                                                  unit: .relative(temperature: t))
                }
            }
        case dewPointAlertControlsCell:
            if let tu = viewModel.temperatureUnit.value {
                viewModel.dewPointLowerBound.value = Temperature(Double(minValue), unit: tu.unitTemperature)
                viewModel.dewPointUpperBound.value = Temperature(Double(maxValue), unit: tu.unitTemperature)
            }
        case pressureAlertControlsCell:
            if let pu = viewModel.pressureUnit.value {
                viewModel.pressureLowerBound.value = Pressure(Double(minValue), unit: pu)
                viewModel.pressureUpperBound.value = Pressure(Double(maxValue), unit: pu)
            }
        default:
            break
        }
    }
}

// MARK: - Bindings
extension WebTagSettingsTableViewController {

    private func bindViewModel() {
        backgroundImageView.bind(viewModel.background) { $0.image = $1 }
        tagNameTextField.bind(viewModel.name) { $0.text = $1 }
        let clearButton = clearLocationButton
        let clearWidth = clearLocationButtonWidth
        locationValueLabel.bind(viewModel.location, block: { [weak clearButton, weak clearWidth] label, location in
            label.text = location?.cityCommaCountry ?? "WebTagSettings.Location.Current".localized()
            clearButton?.isHidden = location == nil
            clearWidth?.constant = location == nil ? 0 : 36
        })

        tableView.bind(viewModel.isLocationAuthorizedAlways) { tableView, _ in
            tableView.reloadData()
        }
        tableView.bind(viewModel.isPushNotificationsEnabled) { tableView, _ in
            tableView.reloadData()
        }
        tableView.bind(viewModel.location) { tableView, _ in
            tableView.reloadData()
        }

        bindTemperatureAlertCells()
        bindHumidityAlertCells()
        bindDewPointAlertCells()
        bindPressureAlertCells()
    }

    // swiftlint:disable:next function_body_length
    private func bindPressureAlertCells() {
        guard isViewLoaded else { return }
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

        pressureAlertHeaderCell.descriptionLabel.bind(viewModel.isPressureAlertOn) {
            [weak self] (_, _) in
            self?.updateUIPressureAlertDescription()
        }

        let isPushNotificationsEnabled = viewModel.isPushNotificationsEnabled
        let isPressureAlertOn = viewModel.isPressureAlertOn
        let isLocationAuthorizedAlways = viewModel.isLocationAuthorizedAlways
        let location = viewModel.location

        pressureAlertHeaderCell.isOnSwitch.bind(viewModel.location) {
            [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways] (view, location) in
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }
        pressureAlertHeaderCell.isOnSwitch.bind(viewModel.isLocationAuthorizedAlways) {
            [weak isPushNotificationsEnabled, weak location] (view, isLocationAuthorizedAlways) in
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways.bound
            let isFixed = location?.value != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }
        pressureAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
            [weak isLocationAuthorizedAlways, weak location] view, isPushNotificationsEnabled in
            let isPN = isPushNotificationsEnabled ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        pressureAlertControlsCell.slider.bind(viewModel.isPressureAlertOn) {
            [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways, weak location]
            (slider, isOn) in
            let isOn = isOn.bound
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }

        pressureAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {

            [weak isPressureAlertOn, weak isLocationAuthorizedAlways, weak location]
            (slider, isPushNotificationsEnabled) in
            let isOn = isPressureAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled.bound
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }

        pressureAlertControlsCell.slider.bind(viewModel.location) {
            [weak isPressureAlertOn, weak isLocationAuthorizedAlways, weak isPushNotificationsEnabled]
            (slider, location) in
            let isOn = isPressureAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }

        pressureAlertControlsCell.slider.bind(viewModel.isLocationAuthorizedAlways) {
            [weak isPressureAlertOn, weak isPushNotificationsEnabled, weak location]
            (slider, isLocationAuthorizedAlways) in
            let isOn = isPressureAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways.bound
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
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
        guard isViewLoaded else { return }
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

        let isPushNotificationsEnabled = viewModel.isPushNotificationsEnabled
        let isRHAlertOn = viewModel.isHumidityAlertOn
        let isLocationAuthorizedAlways = viewModel.isLocationAuthorizedAlways
        let location = viewModel.location

        humidityAlertHeaderCell.isOnSwitch.bind(viewModel.location) {
            [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways] (view, location) in
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }
        humidityAlertHeaderCell.isOnSwitch.bind(viewModel.isLocationAuthorizedAlways) {
            [weak isPushNotificationsEnabled, weak location] (view, isLocationAuthorizedAlways) in
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways.bound
            let isFixed = location?.value != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }
        humidityAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
            [weak isLocationAuthorizedAlways, weak location] view, isPushNotificationsEnabled in
            let isPN = isPushNotificationsEnabled ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        humidityAlertControlsCell.slider.bind(viewModel.isHumidityAlertOn) {
            [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways, weak location]
            (slider, isOn) in
            let isOn = isOn.bound
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }
        humidityAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {

            [weak isRHAlertOn, weak isLocationAuthorizedAlways, weak location]
            (slider, isPushNotificationsEnabled) in
            let isOn = isRHAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled.bound
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }

        humidityAlertControlsCell.slider.bind(viewModel.location) {
            [weak isRHAlertOn, weak isLocationAuthorizedAlways, weak isPushNotificationsEnabled]
            (slider, location) in
            let isOn = isRHAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }

        humidityAlertControlsCell.slider.bind(viewModel.isLocationAuthorizedAlways) {
            [weak isRHAlertOn, weak isPushNotificationsEnabled, weak location]
            (slider, isLocationAuthorizedAlways) in
            let isOn = isRHAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways.bound
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
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
    private func bindTemperatureAlertCells() {
        guard isViewLoaded else { return }

        temperatureAlertControlsCell.slider.bind(viewModel.temperatureUnit) { (slider, temperatureUnit) in
            if let tu = temperatureUnit {
                slider.minValue = CGFloat(tu.alertRange.lowerBound)
                slider.maxValue = CGFloat(tu.alertRange.upperBound)
            }
        }
        temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isTemperatureAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
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
            if let tu = temperatureUnit {
                let title = "WebTagSettings.temperatureAlertTitleLabel.text"
                label.text = title.localized() + " " + tu.symbol
            } else {
                label.text = "N/A".localized()
            }
        }
        temperatureAlertHeaderCell.descriptionLabel.bind(viewModel.isTemperatureAlertOn) { [weak self] (_, _) in
            self?.updateUITemperatureAlertDescription()
        }

        let isPushNotificationsEnabled = viewModel.isPushNotificationsEnabled
        let isTemperatureAlertOn = viewModel.isTemperatureAlertOn
        let isLocationAuthorizedAlways = viewModel.isLocationAuthorizedAlways
        let location = viewModel.location

        temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.location) {
            [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways] (view, location) in
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }
        temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isLocationAuthorizedAlways) {
            [weak isPushNotificationsEnabled, weak location] (view, isLocationAuthorizedAlways) in
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways.bound
            let isFixed = location?.value != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }
        temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
            [weak isLocationAuthorizedAlways, weak location] view, isPushNotificationsEnabled in
            let isPN = isPushNotificationsEnabled ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        temperatureAlertControlsCell.slider.bind(viewModel.isTemperatureAlertOn) {
            [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways, weak location]
            (slider, isOn) in
            let isOn = isOn.bound
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }
        temperatureAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {

            [weak isTemperatureAlertOn, weak isLocationAuthorizedAlways, weak location]
            (slider, isPushNotificationsEnabled) in
            let isOn = isTemperatureAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled.bound
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }

        temperatureAlertControlsCell.slider.bind(viewModel.location) {
            [weak isTemperatureAlertOn, weak isLocationAuthorizedAlways, weak isPushNotificationsEnabled]
            (slider, location) in
            let isOn = isTemperatureAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }

        temperatureAlertControlsCell.slider.bind(viewModel.isLocationAuthorizedAlways) {
            [weak isTemperatureAlertOn, weak isPushNotificationsEnabled, weak location]
            (slider, isLocationAuthorizedAlways) in
            let isOn = isTemperatureAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways.bound
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
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

    // swiftlint:disable:next function_body_length
    private func bindDewPointAlertCells() {
        guard isViewLoaded else {
            return
        }
        dewPointAlertHeaderCell.isOnSwitch.bind(viewModel.isDewPointAlertOn) { (view, isOn) in
            view.isOn = isOn.bound
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
            let title = "WebTagSettings.dewPointAlertTitleLabel.text"
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

        let isPushNotificationsEnabled = viewModel.isPushNotificationsEnabled
        let isDewPointAlertOn = viewModel.isDewPointAlertOn
        let isLocationAuthorizedAlways = viewModel.isLocationAuthorizedAlways
        let location = viewModel.location

        dewPointAlertHeaderCell.isOnSwitch.bind(viewModel.location) {
            [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways] (view, location) in
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        dewPointAlertHeaderCell.isOnSwitch.bind(viewModel.isLocationAuthorizedAlways) {
            [weak isPushNotificationsEnabled, weak location] (view, isLocationAuthorizedAlways) in
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways.bound
            let isFixed = location?.value != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        dewPointAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
            [weak isLocationAuthorizedAlways, weak location] view, isPushNotificationsEnabled in
            let isPN = isPushNotificationsEnabled ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isPN && (isLA || isFixed)
            view.isEnabled = isEnabled
            view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
        }

        dewPointAlertControlsCell.slider.bind(viewModel.isDewPointAlertOn) {
            [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways, weak location]
            (slider, isOn) in
            let isOn = isOn.bound
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }
        dewPointAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {
            [weak isDewPointAlertOn, weak isLocationAuthorizedAlways, weak location]
            (slider, isPushNotificationsEnabled) in
            let isOn = isDewPointAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled.bound
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }

        dewPointAlertControlsCell.slider.bind(viewModel.location) {
            [weak isDewPointAlertOn, weak isLocationAuthorizedAlways, weak isPushNotificationsEnabled]
            (slider, location) in
            let isOn = isDewPointAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways?.value ?? false
            let isFixed = location != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
        }

        dewPointAlertControlsCell.slider.bind(viewModel.isLocationAuthorizedAlways) {
            [weak isDewPointAlertOn, weak isPushNotificationsEnabled, weak location]
            (slider, isLocationAuthorizedAlways) in
            let isOn = isDewPointAlertOn?.value ?? false
            let isPN = isPushNotificationsEnabled?.value ?? false
            let isLA = isLocationAuthorizedAlways.bound
            let isFixed = location?.value != nil
            let isEnabled = isOn && isPN && (isLA || isFixed)
            slider.isEnabled = isEnabled
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
// swiftlint:enable file_length
