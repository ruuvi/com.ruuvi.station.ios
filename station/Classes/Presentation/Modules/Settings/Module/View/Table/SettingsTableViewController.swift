import UIKit
import RuuviOntology

private enum SettingsTableSection: Int {
    case general = 0
    case application = 1
}

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!

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
    @IBOutlet weak var closeBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var languageValueLabel: UILabel!
    @IBOutlet weak var languageTitleLabel: UILabel!
    @IBOutlet weak var languageCell: UITableViewCell!
    @IBOutlet weak var chartCell: UITableViewCell!
    @IBOutlet weak var chartTitleLabel: UILabel!
    @IBOutlet weak var experimentalFunctionsCell: UITableViewCell!
    @IBOutlet weak var experimentalFunctionsLabel: UILabel!

    @IBOutlet weak var cloudModeTitleLabel: UILabel!
    @IBOutlet weak var cloudModeEnableSwitch: UISwitch!
    @IBOutlet weak var cloudModeCell: UITableViewCell!

    #if DEVELOPMENT
    private let showDefaults = true
    #else
    private let showDefaults = false
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
    var cloudModeEnabled: Bool = false {
        didSet {
            cloudModeEnableSwitch.isOn = cloudModeEnabled
        }
    }
}

// MARK: - SettingsViewInput
extension SettingsTableViewController: SettingsViewInput {
    func localize() {
        navigationItem.title = "Settings.navigationItem.title".localized()
        temperatureTitleLabel.text = "TagSettings.OffsetCorrection.Temperature".localized()
        humidityTitleLabel.text = "TagSettings.OffsetCorrection.Humidity".localized()
        pressureTitleLabel.text = "TagSettings.OffsetCorrection.Pressure".localized()
        languageTitleLabel.text = "Settings.Label.Language.text".localized()
        defaultsTitleLabel.text = "Settings.Label.Defaults".localized()
        heartbeatTitleLabel.text = "Settings.BackgroundScanning.title".localized()
        chartTitleLabel.text = "Settings.Label.Chart".localized()
        cloudModeTitleLabel.text = "Settings.Label.CloudMode".localized()
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
        setupLocalization()
        updateUI()
        setupCloudModeCellSwitch()
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
            !cloudModeVisible && cell == cloudModeCell {
            return 0
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case SettingsTableSection.general.rawValue:
            return "Settings.SectionHeader.General.title".localized()
        case SettingsTableSection.application.rawValue:
            return "Settings.SectionHeader.Application.title".localized()
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case SettingsTableSection.application.rawValue:
            return cloudModeVisible ? "Settings.Label.CloudMode.description".localized() : nil
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
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
            case heartbeatCell:
                output.viewDidTapOnHeartbeat()
            case chartCell:
                output.viewDidTapOnChart()
            case experimentalFunctionsCell:
                output.viewDidTapOnExperimental()
            default:
                break
            }
        }
    }
}

// MARK: - Update UI
extension SettingsTableViewController {
    private func updateUI() {
//        updateUITemperatureUnit()
//        updateUIHumidityUnit()
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

    private func setupCloudModeCellSwitch() {
        cloudModeEnableSwitch.addTarget(self,
                                        action: #selector(cloudModeSwitchValueChangeHandler),
                                        for: .valueChanged)
    }

    @objc
    private func cloudModeSwitchValueChangeHandler(_ sender: UISwitch) {
        output.viewCloudModeDidChange(isOn: sender.isOn)
    }
}
