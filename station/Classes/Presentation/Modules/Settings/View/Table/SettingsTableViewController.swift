import UIKit

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!
    
    @IBOutlet weak var humidityUnitSegmentedControl: UISegmentedControl!
    @IBOutlet weak var useFahrenheitSwitch: UISwitch!
    @IBOutlet weak var experimentalUXSwitch: UISwitch?
    
    var temperatureUnit: TemperatureUnit = .celsius { didSet { updateUITemperatureUnit() } }
    var humidityUnit: HumidityUnit = .percent { didSet { updateUIHumidityUnit() } }
    var isExperimentalUX: Bool = false { didSet { updateUIIsExperimentalUX() } }
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
    @IBAction func useFahrenheitSwitchValueChanged(_ sender: Any) {
        output.viewDidChange(temperatureUnit: useFahrenheitSwitch.isOn ? .fahrenheit : .celsius)
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
    
    @IBAction func experimentalUXValueChanged(_ sender: UISwitch) {
        output.viewDidChange(experimentalUX: sender.isOn)
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
        updateUIIsExperimentalUX()
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
    
    private func updateUIIsExperimentalUX() {
        if isViewLoaded {
            experimentalUXSwitch?.isOn = isExperimentalUX
        }
    }
    
    private func updateUITemperatureUnit() {
        if isViewLoaded {
            useFahrenheitSwitch.isOn = temperatureUnit == .fahrenheit
        }
    }
}
