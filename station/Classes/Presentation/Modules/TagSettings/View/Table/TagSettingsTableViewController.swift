import UIKit

class TagSettingsTableViewController: UITableViewController {
    var output: TagSettingsViewOutput!
    
    @IBOutlet weak var accelerationZValueLabel: UILabel!
    @IBOutlet weak var tagNameCell: UITableViewCell!
    @IBOutlet weak var calibrationHumidityCell: UITableViewCell!
    @IBOutlet weak var accelerationYValueLabel: UILabel!
    @IBOutlet weak var accelerationXValueLabel: UILabel!
    @IBOutlet weak var voltageValueLabel: UILabel!
    @IBOutlet weak var macAddressTitleLabel: UILabel!
    @IBOutlet weak var macAddressValueLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tagNameTextField: UITextField!
    
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
            
            let uuid = viewModel.uuid
            let mac = viewModel.mac
            let macTitleLabel = macAddressTitleLabel
            let macValueLabel = macAddressValueLabel
            
            let macBlock: ((UILabel,String?) -> Void) = { [weak uuid, weak mac, weak macTitleLabel, weak macValueLabel] _, _ in
                if let mac = mac?.value {
                    macTitleLabel?.text = "TagSettings.MACTitleLabel.MAC.text".localized()
                    macValueLabel?.text = mac
                } else if let uuid = uuid?.value {
                    macTitleLabel?.text = "TagSettings.MACTitleLabel.UUID.text".localized()
                    macValueLabel?.text = uuid
                } else {
                    macTitleLabel?.text = "TagSettings.MACTitleLabel.MAC.text".localized()
                    macValueLabel?.text = "N/A".localized()
                }
            }
            macAddressValueLabel.bind(viewModel.mac, block: macBlock)
            macAddressValueLabel.bind(viewModel.mac, block: macBlock)
            macAddressValueLabel.bind(viewModel.uuid, block: macBlock)
            macAddressValueLabel.bind(viewModel.uuid, block: macBlock)
            
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
        }
    }
}
