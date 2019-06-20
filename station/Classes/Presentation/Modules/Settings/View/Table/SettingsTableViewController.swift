import UIKit

class SettingsTableViewController: UITableViewController {
    var output: SettingsViewOutput!
    
    @IBOutlet weak var useFahrenheitSwitch: UISwitch!
    @IBOutlet weak var experimentalUXSwitch: UISwitch!
    
    var temperatureUnit: TemperatureUnit = .celsius { didSet { updateUITemperatureUnit() } }
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
    
    @IBAction func experimentalUXValueChanged(_ sender: Any) {
        output.viewDidChange(experimentalUX: experimentalUXSwitch.isOn)
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
        updateUIIsExperimentalUX()
    }
    
    private func updateUIIsExperimentalUX() {
        if isViewLoaded {
            experimentalUXSwitch.isOn = isExperimentalUX
        }
    }
    
    private func updateUITemperatureUnit() {
        if isViewLoaded {
            useFahrenheitSwitch.isOn = temperatureUnit == .fahrenheit
        }
    }
}
