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
    @IBOutlet weak var absoluteHumidityAlertHeaderCell: WebTagSettingsAlertHeaderCell!
    @IBOutlet weak var absoluteHumidityAlertControlsCell: WebTagSettingsAlertControlsCell!
    @IBOutlet weak var relativeHumidityAlertHeaderCell: WebTagSettingsAlertHeaderCell!
    @IBOutlet weak var relativeHumidityAlertControlsCell: WebTagSettingsAlertControlsCell!
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
        relativeHumidityAlertHeaderCell.titleLabel.text
            = "WebTagSettings.RelativeAirHumidityAlert.title".localized()
            + " " + "%".localized()
        absoluteHumidityAlertHeaderCell.titleLabel.text
            = "WebTagSettings.AbsoluteAirHumidityAlert.title".localized()
            + " " + "g/m³".localized()
        pressureAlertHeaderCell.titleLabel.text
            = "WebTagSettings.PressureAlert.title".localized()
            + " " + "hPa".localized()

        let alertPlaceholder = "TagSettings.Alert.CustomDescription.placeholder".localized()
        temperatureAlertControlsCell.textField.placeholder = alertPlaceholder
        relativeHumidityAlertControlsCell.textField.placeholder = alertPlaceholder
        absoluteHumidityAlertControlsCell.textField.placeholder = alertPlaceholder
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
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell {
            case tagNameCell:
                tagNameTextField.becomeFirstResponder()
            case locationCell:
                output.viewDidAskToSelectLocation()
            default:
                break
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        let headerHeight: CGFloat = 66
        let controlsHeight: CGFloat = 148
        let hu = viewModel.humidityUnit.value
        switch cell {
        case temperatureAlertHeaderCell:
            return headerHeight
        case temperatureAlertControlsCell:
            return (viewModel.isTemperatureAlertOn.value ?? false) ? controlsHeight : 0
        case relativeHumidityAlertHeaderCell:
            return (hu == .percent) ? headerHeight : 0
        case relativeHumidityAlertControlsCell:
            return ((hu == .percent) && (viewModel.isRelativeHumidityAlertOn.value ?? false)) ? controlsHeight : 0
        case absoluteHumidityAlertHeaderCell:
            return (hu == .gm3) ? headerHeight : 0
        case absoluteHumidityAlertControlsCell:
            return ((hu == .gm3) && (viewModel.isAbsoluteHumidityAlertOn.value ?? false)) ? controlsHeight : 0
        case dewPointAlertHeaderCell:
            return (hu == .dew) ? headerHeight : 0
        case dewPointAlertControlsCell:
            return ((hu == .dew) && (viewModel.isDewPointAlertOn.value ?? false)) ? controlsHeight : 0
        case pressureAlertHeaderCell:
            return headerHeight
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
        relativeHumidityAlertHeaderCell.delegate = self
        relativeHumidityAlertControlsCell.delegate = self
        absoluteHumidityAlertHeaderCell.delegate = self
        absoluteHumidityAlertControlsCell.delegate = self
        dewPointAlertHeaderCell.delegate = self
        dewPointAlertControlsCell.delegate = self
        pressureAlertHeaderCell.delegate = self
        pressureAlertControlsCell.delegate = self

        configureMinMaxForSliders()
    }

    private func configureMinMaxForSliders() {
        let tu = viewModel.temperatureUnit.value ?? .celsius
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

    private func updateUIPressureLowerBound() {
        if isViewLoaded {
            if let lower = viewModel.pressureLowerBound.value {
                pressureAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
            } else {
                pressureAlertControlsCell.slider.selectedMinValue = 300
            }
        }
    }

    private func updateUIPressureUpperBound() {
        if isViewLoaded {
            if let upper = viewModel.pressureUpperBound.value {
                pressureAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
            } else {
                pressureAlertControlsCell.slider.selectedMaxValue = 1100
            }
        }
    }

    private func updateUIPressureAlertDescription() {
        if isViewLoaded {
            if let isPressureAlertOn = viewModel.isPressureAlertOn.value,
                isPressureAlertOn {
                if let l = viewModel.pressureLowerBound.value,
                    let u = viewModel.pressureUpperBound.value {
                    let format = "WebTagSettings.Alerts.Pressure.description".localized()
                    pressureAlertHeaderCell.descriptionLabel.text = String(format: format, l, u)
                } else {
                    pressureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                pressureAlertHeaderCell.descriptionLabel.text = "TagSettings.Alerts.Off".localized()
            }
        }
    }

    private func updateUIDewPointCelsiusLowerBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel.temperatureUnit.value {
                if let lower = viewModel.dewPointCelsiusLowerBound.value {
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

    private func updateUIDewPointCelsiusUpperBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel.temperatureUnit.value {
                if let upper = viewModel.dewPointCelsiusUpperBound.value {
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

    private func updateUIDewPointAlertDescription() {
        if isViewLoaded {
            if let isDewPointAlertOn = viewModel.isDewPointAlertOn.value, isDewPointAlertOn {
                if let l = viewModel.dewPointCelsiusLowerBound.value,
                    let u = viewModel.dewPointCelsiusUpperBound.value,
                    let tu = viewModel.temperatureUnit.value {
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
                    let format = "WebTagSettings.Alerts.DewPoint.description".localized()
                    dewPointAlertHeaderCell.descriptionLabel.text = String(format: format, la, ua)
                } else {
                    dewPointAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                dewPointAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUIAbsoluteHumidityLowerBound() {
        if isViewLoaded {
            if let lower = viewModel.absoluteHumidityLowerBound.value {
                absoluteHumidityAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
            } else {
                absoluteHumidityAlertControlsCell.slider.selectedMinValue = 0
            }
        }
    }

    private func updateUIAbsoluteHumidityUpperBound() {
        if isViewLoaded {
            if let upper = viewModel.absoluteHumidityUpperBound.value {
                absoluteHumidityAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
            } else {
                absoluteHumidityAlertControlsCell.slider.selectedMaxValue = 40
            }
        }
    }

    private func updateUIAbsoluteHumidityAlertDescription() {
        if isViewLoaded {
            if let isAbsoluteHumidityAlertOn = viewModel.isAbsoluteHumidityAlertOn.value, isAbsoluteHumidityAlertOn {
                if let l = viewModel.absoluteHumidityLowerBound.value,
                    let u = viewModel.absoluteHumidityUpperBound.value {
                    let format = "WebTagSettings.Alerts.AbsoluteHumidity.description".localized()
                    absoluteHumidityAlertHeaderCell.descriptionLabel.text = String(format: format, l, u)
                } else {
                    absoluteHumidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                absoluteHumidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUIRelativeHumidityAlertDescription() {
        if isViewLoaded {
            if let isRelativeHumidityAlertOn = viewModel.isRelativeHumidityAlertOn.value,
                isRelativeHumidityAlertOn {
                if let l = viewModel.relativeHumidityLowerBound.value,
                    let u = viewModel.relativeHumidityUpperBound.value {
                    let format = "WebTagSettings.Alerts.RelativeHumidity.description".localized()
                    relativeHumidityAlertHeaderCell.descriptionLabel.text = String(format: format, l, u)
                } else {
                    relativeHumidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                relativeHumidityAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUIRelativeHumidityLowerBound() {
        if isViewLoaded {
            if let lower = viewModel.relativeHumidityLowerBound.value {
                relativeHumidityAlertControlsCell.slider.selectedMinValue = CGFloat(lower)
            } else {
                relativeHumidityAlertControlsCell.slider.selectedMinValue = 0
            }
        }
    }

    private func updateUIRelativeHumidityUpperBound() {
        if isViewLoaded {
            if let upper = viewModel.relativeHumidityUpperBound.value {
                relativeHumidityAlertControlsCell.slider.selectedMaxValue = CGFloat(upper)
            } else {
                relativeHumidityAlertControlsCell.slider.selectedMaxValue = 100
            }
        }
    }

    private func updateUITemperatureAlertDescription() {
        if isViewLoaded {
            if let isTemperatureAlertOn = viewModel.isTemperatureAlertOn.value, isTemperatureAlertOn {
                if let l = viewModel.celsiusLowerBound.value,
                    let u = viewModel.celsiusUpperBound.value,
                    let tu = viewModel.temperatureUnit.value {
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
                    let format = "WebTagSettings.Alerts.Temperature.description".localized()
                    temperatureAlertHeaderCell.descriptionLabel.text = String(format: format, la, ua)
                } else {
                    temperatureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
                }
            } else {
                temperatureAlertHeaderCell.descriptionLabel.text = alertOffString.localized()
            }
        }
    }

    private func updateUICelsiusLowerBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel.temperatureUnit.value {
                if let lower = viewModel.celsiusLowerBound.value {
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

    private func updateUICelsiusUpperBound() {
        if isViewLoaded {
            if let temperatureUnit = viewModel.temperatureUnit.value {
                if let upper = viewModel.celsiusUpperBound.value {
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
}

// MARK: - WebTagSettingsAlertHeaderCellDelegate
extension WebTagSettingsTableViewController: WebTagSettingsAlertHeaderCellDelegate {
    func webTagSettingsAlertHeader(cell: WebTagSettingsAlertHeaderCell, didToggle isOn: Bool) {
        switch cell {
        case temperatureAlertHeaderCell:
            viewModel.isTemperatureAlertOn.value = isOn
        case relativeHumidityAlertHeaderCell:
            viewModel.isRelativeHumidityAlertOn.value = isOn
        case absoluteHumidityAlertHeaderCell:
            viewModel.isAbsoluteHumidityAlertOn.value = isOn
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
        case relativeHumidityAlertControlsCell:
            viewModel.relativeHumidityAlertDescription.value = description
        case absoluteHumidityAlertControlsCell:
            viewModel.absoluteHumidityAlertDescription.value = description
        case dewPointAlertControlsCell:
            viewModel.dewPointAlertDescription.value = description
        case pressureAlertControlsCell:
            viewModel.pressureAlertDescription.value = description
        default:
            break
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func webTagSettingsAlertControls(cell: WebTagSettingsAlertControlsCell,
                                     didSlideTo minValue: CGFloat,
                                     maxValue: CGFloat) {
        switch cell {
        case temperatureAlertControlsCell:
            if let tu = viewModel.temperatureUnit.value {
                switch tu {
                case .celsius:
                    viewModel.celsiusLowerBound.value = Double(minValue)
                    viewModel.celsiusUpperBound.value = Double(maxValue)
                case .fahrenheit:
                    viewModel.celsiusLowerBound.value = Double(minValue).celsiusFromFahrenheit
                    viewModel.celsiusUpperBound.value = Double(maxValue).celsiusFromFahrenheit
                case .kelvin:
                    viewModel.celsiusLowerBound.value = Double(minValue).celsiusFromKelvin
                    viewModel.celsiusUpperBound.value = Double(maxValue).celsiusFromKelvin
                }
            }
        case relativeHumidityAlertControlsCell:
            viewModel.relativeHumidityLowerBound.value = Double(minValue)
            viewModel.relativeHumidityUpperBound.value = Double(maxValue)
        case absoluteHumidityAlertControlsCell:
            viewModel.absoluteHumidityLowerBound.value = Double(minValue)
            viewModel.absoluteHumidityUpperBound.value = Double(maxValue)
        case dewPointAlertControlsCell:
            if let tu = viewModel.temperatureUnit.value {
                switch tu {
                case .celsius:
                    viewModel.dewPointCelsiusLowerBound.value = Double(minValue)
                    viewModel.dewPointCelsiusUpperBound.value = Double(maxValue)
                case .fahrenheit:
                    viewModel.dewPointCelsiusLowerBound.value = Double(minValue).celsiusFromFahrenheit
                    viewModel.dewPointCelsiusUpperBound.value = Double(maxValue).celsiusFromFahrenheit
                case .kelvin:
                    viewModel.dewPointCelsiusLowerBound.value = Double(minValue).celsiusFromKelvin
                    viewModel.dewPointCelsiusUpperBound.value = Double(maxValue).celsiusFromKelvin
                }
            }
        case pressureAlertControlsCell:
            viewModel.pressureLowerBound.value = Double(minValue)
            viewModel.pressureUpperBound.value = Double(maxValue)
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
        bindRelativeHumidityCells()
        bindAbsoluteHumidityCells()
        bindDewPointAlertCells()
        bindPressureAlertCells()
    }

    // swiftlint:disable:next function_body_length
    private func bindPressureAlertCells() {
        if isViewLoaded {
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
    }

    // swiftlint:disable:next function_body_length
    private func bindDewPointAlertCells() {
        if isViewLoaded {
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
                    let title = "WebTagSettings.dewPointAlertTitleLabel.text"
                    switch tu {
                    case .celsius:
                        label.text = title.localized() + " " + "°C".localized()
                    case .fahrenheit:
                        label.text = title.localized() + " " + "°F".localized()
                    case .kelvin:
                        label.text = title.localized() + " "  + "K".localized()
                    }
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

    // swiftlint:disable:next function_body_length
    private func bindAbsoluteHumidityCells() {
        if isViewLoaded {
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

            let isPushNotificationsEnabled = viewModel.isPushNotificationsEnabled
            let isAHAlertOn = viewModel.isAbsoluteHumidityAlertOn
            let isLocationAuthorizedAlways = viewModel.isLocationAuthorizedAlways
            let location = viewModel.location

            absoluteHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.location) {
                [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways] (view, location) in
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location != nil
                let isEnabled = isPN && (isLA || isFixed)
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }
            absoluteHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isLocationAuthorizedAlways) {
                [weak isPushNotificationsEnabled, weak location] (view, isLocationAuthorizedAlways) in
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways.bound
                let isFixed = location?.value != nil
                let isEnabled = isPN && (isLA || isFixed)
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }
            absoluteHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
                [weak isLocationAuthorizedAlways, weak location] view, isPushNotificationsEnabled in
                let isPN = isPushNotificationsEnabled ?? false
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location?.value != nil
                let isEnabled = isPN && (isLA || isFixed)
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            absoluteHumidityAlertControlsCell.slider.bind(viewModel.isAbsoluteHumidityAlertOn) {
                [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways, weak location]
                (slider, isOn) in
                let isOn = isOn.bound
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location?.value != nil
                let isEnabled = isOn && isPN && (isLA || isFixed)
                slider.isEnabled = isEnabled
            }
            absoluteHumidityAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {

                [weak isAHAlertOn, weak isLocationAuthorizedAlways, weak location]
                (slider, isPushNotificationsEnabled) in
                let isOn = isAHAlertOn?.value ?? false
                let isPN = isPushNotificationsEnabled.bound
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location?.value != nil
                let isEnabled = isOn && isPN && (isLA || isFixed)
                slider.isEnabled = isEnabled
            }

            absoluteHumidityAlertControlsCell.slider.bind(viewModel.location) {
                [weak isAHAlertOn, weak isLocationAuthorizedAlways, weak isPushNotificationsEnabled]
                (slider, location) in
                let isOn = isAHAlertOn?.value ?? false
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location != nil
                let isEnabled = isOn && isPN && (isLA || isFixed)
                slider.isEnabled = isEnabled
            }

            absoluteHumidityAlertControlsCell.slider.bind(viewModel.isLocationAuthorizedAlways) {
                [weak isAHAlertOn, weak isPushNotificationsEnabled, weak location]
                (slider, isLocationAuthorizedAlways) in
                let isOn = isAHAlertOn?.value ?? false
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways.bound
                let isFixed = location?.value != nil
                let isEnabled = isOn && isPN && (isLA || isFixed)
                slider.isEnabled = isEnabled
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
    private func bindRelativeHumidityCells() {
        if isViewLoaded {
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

            let isPushNotificationsEnabled = viewModel.isPushNotificationsEnabled
            let isRHAlertOn = viewModel.isRelativeHumidityAlertOn
            let isLocationAuthorizedAlways = viewModel.isLocationAuthorizedAlways
            let location = viewModel.location

            relativeHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.location) {
                [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways] (view, location) in
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location != nil
                let isEnabled = isPN && (isLA || isFixed)
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }
            relativeHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isLocationAuthorizedAlways) {
                [weak isPushNotificationsEnabled, weak location] (view, isLocationAuthorizedAlways) in
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways.bound
                let isFixed = location?.value != nil
                let isEnabled = isPN && (isLA || isFixed)
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }
            relativeHumidityAlertHeaderCell.isOnSwitch.bind(viewModel.isPushNotificationsEnabled) {
                [weak isLocationAuthorizedAlways, weak location] view, isPushNotificationsEnabled in
                let isPN = isPushNotificationsEnabled ?? false
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location?.value != nil
                let isEnabled = isPN && (isLA || isFixed)
                view.isEnabled = isEnabled
                view.onTintColor = isEnabled ? UISwitch.appearance().onTintColor : .gray
            }

            relativeHumidityAlertControlsCell.slider.bind(viewModel.isRelativeHumidityAlertOn) {
                [weak isPushNotificationsEnabled, weak isLocationAuthorizedAlways, weak location]
                (slider, isOn) in
                let isOn = isOn.bound
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location?.value != nil
                let isEnabled = isOn && isPN && (isLA || isFixed)
                slider.isEnabled = isEnabled
            }
            relativeHumidityAlertControlsCell.slider.bind(viewModel.isPushNotificationsEnabled) {

                [weak isRHAlertOn, weak isLocationAuthorizedAlways, weak location]
                (slider, isPushNotificationsEnabled) in
                let isOn = isRHAlertOn?.value ?? false
                let isPN = isPushNotificationsEnabled.bound
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location?.value != nil
                let isEnabled = isOn && isPN && (isLA || isFixed)
                slider.isEnabled = isEnabled
            }

            relativeHumidityAlertControlsCell.slider.bind(viewModel.location) {
                [weak isRHAlertOn, weak isLocationAuthorizedAlways, weak isPushNotificationsEnabled]
                (slider, location) in
                let isOn = isRHAlertOn?.value ?? false
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways?.value ?? false
                let isFixed = location != nil
                let isEnabled = isOn && isPN && (isLA || isFixed)
                slider.isEnabled = isEnabled
            }

            relativeHumidityAlertControlsCell.slider.bind(viewModel.isLocationAuthorizedAlways) {
                [weak isRHAlertOn, weak isPushNotificationsEnabled, weak location]
                (slider, isLocationAuthorizedAlways) in
                let isOn = isRHAlertOn?.value ?? false
                let isPN = isPushNotificationsEnabled?.value ?? false
                let isLA = isLocationAuthorizedAlways.bound
                let isFixed = location?.value != nil
                let isEnabled = isOn && isPN && (isLA || isFixed)
                slider.isEnabled = isEnabled
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
    private func bindTemperatureAlertCells() {
        if isViewLoaded {

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
            temperatureAlertHeaderCell.isOnSwitch.bind(viewModel.isTemperatureAlertOn) { (view, isOn) in
                view.isOn = isOn.bound
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
                    switch tu {
                    case .celsius:
                        label.text = "WebTagSettings.temperatureAlertTitleLabel.text".localized()
                            + " " + "°C".localized()
                    case .fahrenheit:
                        label.text = "WebTagSettings.temperatureAlertTitleLabel.text".localized()
                            + " " + "°F".localized()
                    case .kelvin:
                        label.text = "WebTagSettings.temperatureAlertTitleLabel.text".localized()
                            + " "  + "K".localized()
                    }
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
    }
}
// swiftlint:enable file_length
