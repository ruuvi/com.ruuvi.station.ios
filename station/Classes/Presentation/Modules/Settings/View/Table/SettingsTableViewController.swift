import UIKit

private enum SettingsTableSection: Int {
    case general = 0
}

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!
    
    @IBOutlet weak var humidityUnitSegmentedControl: UISegmentedControl!
    @IBOutlet weak var temperatureUnitSegmentedControl: UISegmentedControl!
    @IBOutlet weak var closeBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var humidityUnitLabel: UILabel!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    
    var temperatureUnit: TemperatureUnit = .celsius { didSet { updateUITemperatureUnit() } }
    var humidityUnit: HumidityUnit = .percent { didSet { updateUIHumidityUnit() } }
}

// MARK: - SettingsViewInput
extension SettingsTableViewController: SettingsViewInput {
    func localize() {
        navigationItem.title = "Settings.navigationItem.title".localized()
        closeBarButtonItem.title = "Settings.BarButtonItem.Close.title".localized()
        temperatureUnitLabel.text = "Settings.Label.TemperatureUnit.text".localized()
        humidityUnitLabel.text = "Settings.Label.HumidityUnit.text".localized()
        humidityUnitSegmentedControl.setTitle("Settings.SegmentedControl.Humidity.Relative.title".localized(), forSegmentAt: 0)
        humidityUnitSegmentedControl.setTitle("Settings.SegmentedControl.Humidity.Absolute.title".localized(), forSegmentAt: 1)
        humidityUnitSegmentedControl.setTitle("Settings.SegmentedControl.Humidity.DewPoint.title".localized(), forSegmentAt: 2)
        tableView.reloadData()
    }
    
    func apply(theme: Theme) {
        
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
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case SettingsTableSection.general.rawValue:
            return "Settings.SectionHeader.General.title".localized()
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case SettingsTableSection.general.rawValue:
            return "Settings.SectionFooter.General.title".localized()
        default:
            return nil
        }
    }
}

// MARK: - Update UI
extension SettingsTableViewController {
    private func updateUI() {
        updateUITemperatureUnit()
        updateUIHumidityUnit()
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
