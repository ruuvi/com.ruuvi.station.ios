import UIKit

private enum SettingsTableSection: Int {
    case general = 0
    case application = 1
    case network = 2
}

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!

    @IBOutlet weak var heartbeatTitleLabel: UILabel!
    @IBOutlet weak var heartbeatCell: UITableViewCell!
    @IBOutlet weak var defaultsTitleLabel: UILabel!
    @IBOutlet weak var defaultsCell: UITableViewCell!
    @IBOutlet weak var humidityUnitSegmentedControl: UISegmentedControl!
    @IBOutlet weak var temperatureUnitSegmentedControl: UISegmentedControl!
    @IBOutlet weak var closeBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var humidityUnitLabel: UILabel!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    @IBOutlet weak var languageValueLabel: UILabel!
    @IBOutlet weak var languageTitleLabel: UILabel!
    @IBOutlet weak var languageCell: UITableViewCell!
    @IBOutlet weak var foregroundCell: UITableViewCell!
    @IBOutlet weak var foregroundTitleLabel: UILabel!
    @IBOutlet weak var advancedCell: UITableViewCell!
    @IBOutlet weak var advancedTitleLabel: UILabel!
    @IBOutlet weak var networkSettingsTitleLabel: UILabel!
    @IBOutlet weak var networkSettingsCell: UITableViewCell!

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
        temperatureUnitLabel.text = "Settings.Label.TemperatureUnit.text".localized()
        humidityUnitLabel.text = "Settings.Label.HumidityUnit.text".localized()
        humidityUnitSegmentedControl.setTitle("Settings.SegmentedControl.Humidity.Relative.title".localized(),
                                              forSegmentAt: 0)
        humidityUnitSegmentedControl.setTitle("Settings.SegmentedControl.Humidity.Absolute.title".localized(),
                                              forSegmentAt: 1)
        humidityUnitSegmentedControl.setTitle("Settings.SegmentedControl.Humidity.DewPoint.title".localized(),
                                              forSegmentAt: 2)
        languageTitleLabel.text = "Settings.Label.Language.text".localized()
        foregroundTitleLabel.text = "Settings.Label.Foreground".localized()
        defaultsTitleLabel.text = "Settings.Label.Defaults".localized()
        heartbeatTitleLabel.text = "Settings.Label.Heartbeat".localized()
        advancedTitleLabel.text = "Settings.Label.Advanced".localized()
        networkSettingsTitleLabel.text = "Settings.Label.NetworkSettings".localized()
        updateUILanguage()
        tableView.reloadData()
    }
}

// MARK: - IBActions
extension SettingsTableViewController {

    @IBAction func temperatureUnitSegmentedControlValueChanged(_ sender: Any) {
        switch temperatureUnitSegmentedControl.selectedSegmentIndex {
        case 0:
            output.viewDidChange(temperatureUnit: .kelvin)
        case 1:
            output.viewDidChange(temperatureUnit: .celsius)
        case 2:
            output.viewDidChange(temperatureUnit: .fahrenheit)
        default:
            break
        }
    }

    @IBAction func humidityUnitSegmentedControlValueChanged(_ sender: Any) {
        switch humidityUnitSegmentedControl.selectedSegmentIndex {
        case 0:
            output.viewDidChange(humidityUnit: .percent)
        case 1:
            output.viewDidChange(humidityUnit: .gm3)
        case 2:
            output.viewDidChange(humidityUnit: .dew)
        default:
            break
        }
    }

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
        case SettingsTableSection.network.rawValue:
            return "Settings.SectionHeader.Network.title".localized()
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == SettingsTableSection.general.rawValue {
            return "Settings.SectionFooter.General.title".localized()
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell {
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
            case networkSettingsCell:
                output.viewDidTapOnKaltiot()
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

    private func updateUIHumidityUnit() {
        if isViewLoaded {
            switch humidityUnit {
            case .percent:
                humidityUnitSegmentedControl.selectedSegmentIndex = 0
            case .gm3:
                humidityUnitSegmentedControl.selectedSegmentIndex = 1
            case .dew:
                humidityUnitSegmentedControl.selectedSegmentIndex = 2
            }
        }
    }

    private func updateUITemperatureUnit() {
        if isViewLoaded {
            switch temperatureUnit {
            case .kelvin:
                temperatureUnitSegmentedControl.selectedSegmentIndex = 0
            case .celsius:
                temperatureUnitSegmentedControl.selectedSegmentIndex = 1
            case .fahrenheit:
                temperatureUnitSegmentedControl.selectedSegmentIndex = 2
            }
        }
    }
}
