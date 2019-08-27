import UIKit

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!
    
    @IBOutlet weak var humidityUnitSegmentedControl: UISegmentedControl!
    @IBOutlet weak var temperatureUnitSegmentedControl: UISegmentedControl!
    
    var temperatureUnit: TemperatureUnit = .celsius { didSet { updateUITemperatureUnit() } }
    var humidityUnit: HumidityUnit = .percent { didSet { updateUIHumidityUnit() } }
}

// MARK: - SettingsViewInput
extension SettingsTableViewController: SettingsViewInput {
    func localize() {
        
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
        updateUI()
        output.viewDidLoad()
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
