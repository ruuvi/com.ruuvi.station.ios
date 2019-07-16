import UIKit

class TagSettingsTableViewController: UITableViewController {
    var output: TagSettingsViewOutput!
    
    @IBOutlet weak var uuidCell: UITableViewCell!
    @IBOutlet weak var macAddressCell: UITableViewCell!
    @IBOutlet weak var tagNameCell: UITableViewCell!
    @IBOutlet weak var calibrationHumidityCell: UITableViewCell!
    @IBOutlet weak var uuidValueLabel: UILabel!
    @IBOutlet weak var accelerationXValueLabel: UILabel!
    @IBOutlet weak var accelerationYValueLabel: UILabel!
    @IBOutlet weak var accelerationZValueLabel: UILabel!
    @IBOutlet weak var voltageValueLabel: UILabel!
    @IBOutlet weak var macAddressValueLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tagNameTextField: UITextField!
    @IBOutlet weak var dataFormatValueLabel: UILabel!
    @IBOutlet weak var mcValueLabel: UILabel!
    @IBOutlet weak var msnValueLabel: UILabel!
    @IBOutlet weak var txPowerValueLabel: UILabel!
    
    var viewModel: TagSettingsViewModel? { didSet { bindTagSettingsViewModel() } }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
}

// MARK: - TagSettingsViewInput
extension TagSettingsTableViewController: TagSettingsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
    
    func showTagRemovalConfirmationDialog() {
        let controller = UIAlertController(title: "TagSettings.confirmTagRemovalDialog.title".localized(), message: "TagSettings.confirmTagRemovalDialog.message".localized(), preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(), style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidConfirmTagRemoval()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
    
    func showMacAddressDetail() {
        let title = "TagSettings.Mac.Alert.title".localized()
        let controller = UIAlertController(title: title, message: viewModel?.mac.value, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Copy".localized(), style: .default, handler: { [weak self] _ in
            if let mac = self?.viewModel?.mac.value {
                UIPasteboard.general.string = mac
            }
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
    
    func showUUIDDetail() {
        let title = "TagSettings.UUID.Alert.title".localized()
        let controller = UIAlertController(title: title, message: viewModel?.uuid.value, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Copy".localized(), style: .default, handler: { [weak self] _ in
            if let uuid = self?.viewModel?.uuid.value {
                UIPasteboard.general.string = uuid
            }
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
    
    func showUpdateFirmwareDialog() {
        let title = "TagSettings.UpdateFirmware.Alert.title".localized()
        let message = "TagSettings.UpdateFirmware.Alert.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "TagSettings.UpdateFirmware.Alert.Buttons.LearnMore.title".localized(), style: .default, handler: { [weak self] _ in
            self?.output.viewDidAskToLearnMoreAboutFirmwareUpdate()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

// MARK: - IBActions
extension TagSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModels()
    }
}
    
// MARK: - IBActions
extension TagSettingsTableViewController {
    @IBAction func dismissBarButtonItemAction(_ sender: Any) {
        output.viewDidAskToDismiss()
    }
    
    @IBAction func removeThisRuuviTagButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToRemoveRuuviTag()
    }
    
    @IBAction func randomizeBackgroundButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToRandomizeBackground()
    }
    
    @IBAction func selectBackgroundButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToSelectBackground()
    }
    
    @IBAction func tagNameTextFieldEditingDidEnd(_ sender: Any) {
        if let name = tagNameTextField.text {
            output.viewDidChangeTag(name: name)
        }
    }
}

// MARK: - UITableViewDelegate
extension TagSettingsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell {
            case tagNameCell:
                tagNameTextField.becomeFirstResponder()
            case calibrationHumidityCell:
                output.viewDidAskToCalibrateHumidity()
            case macAddressCell:
                output.viewDidTapOnMacAddress()
            case uuidCell:
                output.viewDidTapOnUUID()
            default:
                break
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension TagSettingsTableViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: - Bindings
extension TagSettingsTableViewController {
    private func bindViewModels() {
        bindTagSettingsViewModel()
    }
    private func bindTagSettingsViewModel() {
        if isViewLoaded, let viewModel = viewModel {
            backgroundImageView.bind(viewModel.background) { $0.image = $1 }
            tagNameTextField.bind(viewModel.name) { $0.text = $1 }
            
            let humidity = viewModel.humidity
            let humidityOffset = viewModel.humidityOffset
            let humidityBlock: ((UILabel,Double?) -> Void) = { [weak humidity, weak humidityOffset] label, _ in
                if let humidity = humidity?.value, let humidityOffset = humidityOffset?.value {
                    if humidityOffset > 0 {
                        label.text = "\(String(format: "%.2f", humidity))" + " → " + "\(String(format: "%.2f", humidity + humidityOffset))"
                    } else {
                        label.text = nil
                    }
                } else {
                    label.text = nil
                }
            }
            
            humidityLabel.bind(viewModel.humidity, block: humidityBlock)
            humidityLabel.bind(viewModel.humidityOffset, block: humidityBlock)
            
            uuidValueLabel.bind(viewModel.uuid) { label, uuid in
                if let uuid = uuid {
                    label.text = uuid
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            macAddressValueLabel.bind(viewModel.mac) { label, mac in
                if let mac = mac {
                    label.text = mac
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            voltageValueLabel.bind(viewModel.voltage) { label, voltage in
                if let voltage = voltage {
                    label.text = String(format: "%.3f", voltage) + " " + "V".localized()
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            accelerationXValueLabel.bind(viewModel.accelerationX) { label, accelerationX in
                if let accelerationX = accelerationX {
                    label.text = String(format: "%.3f", accelerationX)
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            accelerationYValueLabel.bind(viewModel.accelerationY) { label, accelerationY in
                if let accelerationY = accelerationY {
                    label.text = String(format: "%.3f", accelerationY)
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            accelerationZValueLabel.bind(viewModel.accelerationZ) { label, accelerationZ in
                if let accelerationZ = accelerationZ {
                    label.text = String(format: "%.3f", accelerationZ)
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            dataFormatValueLabel.bind(viewModel.version) { (label, version) in
                if let version = version {
                    label.text = "\(version)"
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            mcValueLabel.bind(viewModel.movementCounter) { (label, mc) in
                if let mc = mc {
                    label.text = "\(mc)"
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            msnValueLabel.bind(viewModel.measurementSequenceNumber) { (label, msn) in
                if let msn = msn {
                    label.text = "\(msn)"
                } else {
                    label.text = "N/A".localized()
                }
            }
            
            txPowerValueLabel.bind(viewModel.txPower) { (label, txPower) in
                if let txPower = txPower {
                    label.text = "\(txPower)"
                } else {
                    label.text = "N/A".localized()
                }
            }
        }
    }
}
