import UIKit
import DateToolsSwift

class RuuviTagViewController: UIViewController {

    var output: RuuviTagViewOutput!
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var uuidLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var pressureLabel: UILabel!
    @IBOutlet weak var rssiLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    @IBOutlet weak var checkmarkButton: UIButton!
    
    var name: String? { didSet { updateUIName() } }
    var uuid: String? { didSet { updateUIUUID() } }
    var temperature: Double? { didSet { updateUITemperature() } }
    var temperatureUnit: TemperatureUnit? { didSet { updateUITemperatureUnit() } }
    var humidity: Double? { didSet { updateUIHumidity() } }
    var pressure: Double? { didSet { updateUIPressure() } }
    var rssi: Int? { didSet { updateUIRssi() } }
    var updated: Date? { didSet { updateUIUpdated() } }
    
}

// MARK: - RuuviTagViewInput
extension RuuviTagViewController: RuuviTagViewInput {
    func apply(theme: Theme) {
        
    }
    
    func localize() {
        
    }
}

// MARK: - IBActions
extension RuuviTagViewController {
    
    @IBAction func checkmarkButtonTouchUpInside(_ sender: Any) {
        if let name = nameTextField.text, !name.isEmpty {
            output.viewDidSave(name: name)
        }
    }
    
    @IBAction func viewGestureRecognizerAction(_ sender: Any) {
        output.viewDidTapOnView()
    }
    
    @IBAction func nameTextFieldEditingChanged(_ sender: Any) {
        updateUIIsCheckmarkEnabled()
    }
}

// MARK: - View lifecycle
extension RuuviTagViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        registerForNotifications()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextField.becomeFirstResponder()
    }
}

// MARK: - UITextFieldDelegate
extension RuuviTagViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if textField == nameTextField,
            let name = nameTextField.text, !name.isEmpty {
            output.viewDidSave(name: name)
        }
        return false
    }
}

// MARK: - Notifications
extension RuuviTagViewController {
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(RuuviTagViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(RuuviTagViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let margin = CGFloat(16)
            view.frame.origin.y = UIScreen.main.bounds.size.height - keyboardSize.height - view.frame.size.height - margin
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        view.frame.origin.y = (UIScreen.main.bounds.height / 2.0) - (view.frame.size.height / 2.0)
    }
}

// MARK: - UpdateUI
extension RuuviTagViewController {
    private func updateUI() {
        updateUIName()
        updateUIUUID()
        updateUITemperature()
        updateUITemperatureUnit()
        updateUIHumidity()
        updateUIPressure()
        updateUIRssi()
        updateUIUpdated()
        updateUIIsCheckmarkEnabled()
    }
    
    private func updateUIName() {
        if isViewLoaded {
            nameTextField.text = name
        }
    }
    
    private func updateUIIsCheckmarkEnabled() {
        if isViewLoaded {
            if let name = nameTextField.text {
                checkmarkButton.isEnabled = !name.isEmpty
            } else {
                checkmarkButton.isEnabled = false
            }
        }
    }
    
    private func updateUIUpdated() {
        if isViewLoaded {
            if let updated = updated {
                updatedLabel.text = updated.timeAgoSinceNow
            } else {
                updatedLabel.text = nil
            }
        }
    }
    
    private func updateUIRssi() {
        if isViewLoaded {
            if let rssi = rssi {
                rssiLabel.text = "\(rssi) dBm"
            } else {
                rssiLabel.text = nil
            }
        }
    }
    
    private func updateUIPressure() {
        if isViewLoaded {
            if let pressure = pressure {
                pressureLabel.text = "\(pressure) hPa"
            } else {
                pressureLabel.text = nil
            }
        }
    }
    
    private func updateUIHumidity() {
        if isViewLoaded {
            if let humidity = humidity {
                humidityLabel.text = String(format: "%.2f", humidity) + " %"
            } else {
                humidityLabel.text = nil
            }
        }
    }
    
    private func updateUITemperatureUnit() {
        if isViewLoaded {
            if let temperatureUnit = temperatureUnit {
                switch temperatureUnit {
                case .celsius:
                    temperatureUnitLabel.text = "°C"
                case .fahrenheit:
                    temperatureUnitLabel.text = "°F"
                }
            } else {
                temperatureUnitLabel.text = nil
            }
        }
    }
    
    private func updateUITemperature() {
        if isViewLoaded {
            if let temperature = temperature {
                temperatureLabel.text = String(format: "%.2f", temperature)
            } else {
                temperatureLabel.text = nil
            }
        }
    }
    
    private func updateUIUUID() {
        if isViewLoaded {
            uuidLabel.text = uuid
        }
    }
}
