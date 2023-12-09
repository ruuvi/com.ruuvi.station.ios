import RuuviLocalization
import RuuviOntology
import UIKit

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!

    @IBOutlet var alertNotificationsCell: UITableViewCell!
    @IBOutlet var alertNotificationsTitleLabel: UILabel!

    @IBOutlet var appearanceCell: UITableViewCell!
    @IBOutlet var appearanceTitleLabel: UILabel!

    @IBOutlet var temperatureTitleLabel: UILabel!
    @IBOutlet var temperatureCell: UITableViewCell!

    @IBOutlet var humidityTitleLabel: UILabel!
    @IBOutlet var humidityCell: UITableViewCell!

    @IBOutlet var pressureTitleLabel: UILabel!
    @IBOutlet var pressureCell: UITableViewCell!

    @IBOutlet var heartbeatTitleLabel: UILabel!
    @IBOutlet var heartbeatCell: UITableViewCell!

    @IBOutlet var defaultsTitleLabel: UILabel!
    @IBOutlet var defaultsCell: UITableViewCell!

    @IBOutlet var devicesTitleLabel: UILabel!
    @IBOutlet var devicesCell: UITableViewCell!

    @IBOutlet var closeBarButtonItem: UIBarButtonItem!

    @IBOutlet var languageValueLabel: UILabel!
    @IBOutlet var languageTitleLabel: UILabel!
    @IBOutlet var languageCell: UITableViewCell!

    @IBOutlet var chartCell: UITableViewCell!
    @IBOutlet var chartTitleLabel: UILabel!

    @IBOutlet var experimentalFunctionsCell: UITableViewCell!
    @IBOutlet var experimentalFunctionsLabel: UILabel!

    @IBOutlet var ruuviCloudTitleLabel: UILabel!
    @IBOutlet var ruuviCloudCell: UITableViewCell!

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
        navigationItem.title = RuuviLocalization.Settings.NavigationItem.title
        temperatureTitleLabel.text = RuuviLocalization.Settings.Label.temperature
        humidityTitleLabel.text = RuuviLocalization.Settings.Label.humidity
        pressureTitleLabel.text = RuuviLocalization.Settings.Label.pressure
        languageTitleLabel.text = RuuviLocalization.Settings.Label.Language.text
        defaultsTitleLabel.text = RuuviLocalization.Settings.Label.defaults
        devicesTitleLabel.text = RuuviLocalization.DfuDevicesScanner.Title.text
        heartbeatTitleLabel.text = RuuviLocalization.Settings.BackgroundScanning.title
        chartTitleLabel.text = RuuviLocalization.Settings.Label.chart
        ruuviCloudTitleLabel.text = RuuviLocalization.ruuviCloud
        appearanceTitleLabel.text = RuuviLocalization.settingsAppearance
        alertNotificationsTitleLabel.text = RuuviLocalization.settingsAlertNotifications
        updateUILanguage()
        tableView.reloadData()
    }

    func viewDidShowLanguageChangeDialog() {
        let title = RuuviLocalization.Settings.Language.Dialog.title
        let message = RuuviLocalization.Settings.Language.Dialog.message
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelTitle = RuuviLocalization.cancel
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: nil))
        let settingsTitle = RuuviLocalization.WebTagSettings.AlertsAreDisabled.Dialog.Settings.title
        alert.addAction(UIAlertAction(title: settingsTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidSelectChangeLanguage()
        }))
        present(alert, animated: true)
    }
}

// MARK: - IBActions

extension SettingsTableViewController {
    @IBAction func closeBarButtonItemAction(_: Any) {
        output.viewDidTriggerClose()
    }
}

// MARK: - View lifecycle

extension SettingsTableViewController {
    override var canBecomeFirstResponder: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateNavBarTitleFont()
        updateUI()
        output.viewDidLoad()
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with _: UIEvent?) {
        if motion == .motionShake, !experimentalFunctionsEnabled {
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
    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
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
