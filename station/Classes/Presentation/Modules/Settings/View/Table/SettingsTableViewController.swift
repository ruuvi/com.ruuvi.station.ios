import UIKit

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!
    
    @IBOutlet weak var useFahrenheitSwitch: UISwitch!
    
    var temperatureUnit: TemperatureUnit = .celsius { didSet { updateUITemperatureUnit() } }
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
    }
    private func updateUITemperatureUnit() {
        if isViewLoaded {
            useFahrenheitSwitch.isOn = temperatureUnit == .fahrenheit
        }
    }
}
