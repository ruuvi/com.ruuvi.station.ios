import UIKit
import RuuviOntology

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!

    @IBOutlet weak var alertNotificationsCell: UITableViewCell!
    @IBOutlet weak var alertNotificationsTitleLabel: UILabel!

    @IBOutlet weak var appearanceCell: UITableViewCell!
    @IBOutlet weak var appearanceTitleLabel: UILabel!

    @IBOutlet weak var temperatureTitleLabel: UILabel!
    @IBOutlet weak var temperatureCell: UITableViewCell!

    @IBOutlet weak var humidityTitleLabel: UILabel!
    @IBOutlet weak var humidityCell: UITableViewCell!

    @IBOutlet weak var pressureTitleLabel: UILabel!
    @IBOutlet weak var pressureCell: UITableViewCell!

    @IBOutlet weak var heartbeatTitleLabel: UILabel!
    @IBOutlet weak var heartbeatCell: UITableViewCell!

    @IBOutlet weak var defaultsTitleLabel: UILabel!
    @IBOutlet weak var defaultsCell: UITableViewCell!

    @IBOutlet weak var devicesTitleLabel: UILabel!
    @IBOutlet weak var devicesCell: UITableViewCell!

    @IBOutlet weak var closeBarButtonItem: UIBarButtonItem!

    @IBOutlet weak var languageValueLabel: UILabel!
    @IBOutlet weak var languageTitleLabel: UILabel!
    @IBOutlet weak var languageCell: UITableViewCell!

    @IBOutlet weak var chartCell: UITableViewCell!
    @IBOutlet weak var chartTitleLabel: UILabel!

    @IBOutlet weak var experimentalFunctionsCell: UITableViewCell!
    @IBOutlet weak var experimentalFunctionsLabel: UILabel!

    @IBOutlet weak var ruuviCloudTitleLabel: UILabel!
    @IBOutlet weak var ruuviCloudCell: UITableViewCell!

    #if DEVELOPMENT
    private let showDefaults = true
    private let showDevices = true
    #else
    private let showDefaults = false
    private let showDevices = false
    #endif

    var language: Language = .english {
        didSet {
            updateUILanguage()
        }
    }

    var experimentalFunctionsEnabled: Bool = false {
        didSet {
            updateTableIfLoaded()
        }
    }
    var cloudModeVisible: Bool = false {
        didSet {
            updateTableIfLoaded()
        }
    }
}

// MARK: - SettingsViewInput
extension SettingsTableViewController: SettingsViewInput {
    func localize() {
        navigationItem.title = "Settings.navigationItem.title".localized()
        temperatureTitleLabel.text = "Settings.Label.Temperature".localized()
        humidityTitleLabel.text = "Settings.Label.Humidity".localized()
        pressureTitleLabel.text = "Settings.Label.Pressure".localized()
        languageTitleLabel.text = "Settings.Label.Language.text".localized()
        defaultsTitleLabel.text = "Settings.Label.Defaults".localized()
        devicesTitleLabel.text = "DfuDevicesScanner.Title.text".localized()
        heartbeatTitleLabel.text = "Settings.BackgroundScanning.title".localized()
        chartTitleLabel.text = "Settings.Label.Chart".localized()
        ruuviCloudTitleLabel.text = "ruuvi_cloud".localized()
        appearanceTitleLabel.text = "settings_appearance".localized()
        alertNotificationsTitleLabel.text = "settings_alert_notifications".localized()
        updateUILanguage()
        tableView.reloadData()
    }

    func viewDidShowLanguageChangeDialog() {
        let title = "Settings.Language.Dialog.title".localized()
        let message = "Settings.Language.Dialog.message".localized()
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelTitle = "Cancel".localized()
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: nil))
        let settingsTitle = "WebTagSettings.AlertsAreDisabled.Dialog.Settings.title".localized()
        alert.addAction(UIAlertAction(title: settingsTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidSelectChangeLanguage()
        }))
        present(alert, animated: true)
    }
}

// MARK: - IBActions
extension SettingsTableViewController {

    @IBAction func closeBarButtonItemAction(_ sender: Any) {
        output.viewDidTriggerClose()
    }
}

// MARK: - View lifecycle
extension SettingsTableViewController {
    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateNavBarTitleFont()
        setupLocalization()
        updateUI()
        output.viewDidLoad()
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake && !experimentalFunctionsEnabled {
            output.viewDidTriggerShake()
        }
    }
}

// MARK: - UITableViewDelegate
extension SettingsTableViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if cell == experimentalFunctionsCell {
            return experimentalFunctionsEnabled
                ? super.tableView(tableView, heightForRowAt: indexPath)
                : 0
        }
        // Add the logic for the cloud mode cell here
        if !showDefaults && cell == defaultsCell ||
           (!showDevices || !cloudModeVisible) && cell == devicesCell ||
            !cloudModeVisible && cell == ruuviCloudCell {
            return 0
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        switch cell {
        case temperatureCell:
            output.viewDidTapTemperatureUnit()
        case humidityCell:
            output.viewDidTapHumidityUnit()
        case pressureCell:
            output.viewDidTapOnPressure()
        case languageCell:
            output.viewDidTapOnLanguage()
        case defaultsCell:
            output.viewDidTapOnDefaults()
        case devicesCell:
            output.viewDidTapOnDevices()
        case heartbeatCell:
            output.viewDidTapOnHeartbeat()
        case chartCell:
            output.viewDidTapOnChart()
        case experimentalFunctionsCell:
            output.viewDidTapOnExperimental()
        case ruuviCloudCell:
            output.viewDidTapRuuviCloud()
        case appearanceCell:
            output.viewDidTapAppearance()
        case alertNotificationsCell:
            output.viewDidTapAlertNotifications()
        default:
            break
        }
    }
}

// MARK: - Update UI
extension SettingsTableViewController {
    private func updateUI() {
        updateUILanguage()
        updateTableIfLoaded()
    }

    private func updateTableIfLoaded() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }

    private func updateUILanguage() {
        if isViewLoaded {
            languageValueLabel.text = language.name
        }
    }

    private func updateNavBarTitleFont() {
        navigationController?.navigationBar.titleTextAttributes =
            [NSAttributedString.Key.font: UIFont.Muli(.bold, size: 18)]
    }
}
