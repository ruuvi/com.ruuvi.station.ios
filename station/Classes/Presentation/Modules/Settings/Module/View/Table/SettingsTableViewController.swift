import UIKit

private enum SettingsTableSection: Int {
    case general = 0
    case application = 1
}

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!

    @IBOutlet weak var temperatureTitleLabel: UILabel!
    @IBOutlet weak var temperatureSubtitleLabel: UILabel!
    @IBOutlet weak var temperatureCell: UITableViewCell!

    @IBOutlet weak var humidityTitleLabel: UILabel!
    @IBOutlet weak var humiditySubtitleLabel: UILabel!
    @IBOutlet weak var humidityCell: UITableViewCell!

    @IBOutlet weak var pressureTitleLabel: UILabel!
    @IBOutlet weak var pressureSubitleLabel: UILabel!
    @IBOutlet weak var pressureCell: UITableViewCell!

    @IBOutlet weak var heartbeatTitleLabel: UILabel!
    @IBOutlet weak var heartbeatCell: UITableViewCell!
    @IBOutlet weak var defaultsTitleLabel: UILabel!
    @IBOutlet weak var defaultsCell: UITableViewCell!
    @IBOutlet weak var closeBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var languageValueLabel: UILabel!
    @IBOutlet weak var languageTitleLabel: UILabel!
    @IBOutlet weak var languageCell: UITableViewCell!
    @IBOutlet weak var foregroundCell: UITableViewCell!
    @IBOutlet weak var foregroundTitleLabel: UILabel!
    @IBOutlet weak var advancedCell: UITableViewCell!
    @IBOutlet weak var advancedTitleLabel: UILabel!

    #if DEVELOPMENT
    private let showDefaults = true
    #else
    private let showDefaults = false
    #endif

    var temperatureUnit: TemperatureUnit = .celsius {
        didSet {
            updateUITemperatureUnit()
        }
    }
    var humidityUnit: HumidityUnit = .percent {
        didSet {
            updateUIHumidityUnit()
        }
    }
    var pressureUnit: UnitPressure = .hectopascals {
        didSet {
            updateUIPressureUnit()
        }
    }
    var language: Language = .english {
        didSet {
            updateUILanguage()
        }
    }
    var isBackgroundVisible: Bool = false {
        didSet {
            updateTableIfLoaded()
        }
    }
    var isAdvancedVisible: Bool = false {
        didSet {
            updateTableIfLoaded()
        }
    }
}

// MARK: - SettingsViewInput
extension SettingsTableViewController: SettingsViewInput {
    func localize() {
        navigationItem.title = "Settings.navigationItem.title".localized()
        temperatureTitleLabel.text = "Settings.Label.TemperatureUnit.text".localized()
        temperatureSubtitleLabel.text = temperatureUnit.title
        humidityTitleLabel.text = "Settings.Label.HumidityUnit.text".localized()
        if humidityUnit == .dew {
            humiditySubtitleLabel.text = String(format: humidityUnit.title, temperatureUnit.symbol)
        } else {
            humiditySubtitleLabel.text = humidityUnit.title
        }
        pressureTitleLabel.text = "Settings.Label.PressureUnit.text".localized()
        pressureSubitleLabel.text = pressureUnit.title
        languageTitleLabel.text = "Settings.Label.Language.text".localized()
        foregroundTitleLabel.text = "Settings.Label.Foreground".localized()
        defaultsTitleLabel.text = "Settings.Label.Defaults".localized()
        heartbeatTitleLabel.text = "Settings.Label.Heartbeat".localized()
        advancedTitleLabel.text = "Settings.Label.Advanced".localized()
        updateUILanguage()
        tableView.reloadData()
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
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        updateUI()
        output.viewDidLoad()
    }
}

// MARK: - UITableViewDelegate
extension SettingsTableViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if !isBackgroundVisible && cell == heartbeatCell ||
            !showDefaults && cell == defaultsCell ||
            !isAdvancedVisible && cell == advancedCell {
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
            case foregroundCell:
                output.viewDidTapOnForeground()
            case defaultsCell:
                output.viewDidTapOnDefaults()
            case heartbeatCell:
                output.viewDidTapOnHeartbeat()
            case advancedCell:
                output.viewDidTapOnAdvanced()
            default:
                break
            }
        }
    }
}

// MARK: - Update UI
extension SettingsTableViewController {
    private func updateUI() {
        updateUITemperatureUnit()
        updateUIHumidityUnit()
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

    private func updateUITemperatureUnit() {
        if isViewLoaded {
            if humidityUnit == .dew {
                updateUIHumidityUnit()
            }
            temperatureSubtitleLabel.text = temperatureUnit.title
        }
    }

    private func updateUIHumidityUnit() {
        if isViewLoaded {
            if humidityUnit == .dew {
                humiditySubtitleLabel.text = String(format: humidityUnit.title, temperatureUnit.symbol)
            } else {
                humiditySubtitleLabel.text = humidityUnit.title
            }
        }
    }

    private func updateUIPressureUnit() {
        if isViewLoaded {
            pressureSubitleLabel.text = pressureUnit.title
        }
    }
}
