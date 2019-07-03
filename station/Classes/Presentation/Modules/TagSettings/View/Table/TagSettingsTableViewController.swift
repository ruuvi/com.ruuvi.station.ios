import UIKit

class TagSettingsTableViewController: UITableViewController {
    var output: TagSettingsViewOutput!
    
    @IBOutlet weak var accelerationZValueLabel: UILabel!
    @IBOutlet weak var accelerationYValueLabel: UILabel!
    @IBOutlet weak var accelerationXValueLabel: UILabel!
    @IBOutlet weak var voltageValueLabel: UILabel!
    @IBOutlet weak var macAddressTitleLabel: UILabel!
    @IBOutlet weak var macAddressValueLabel: UILabel!
    @IBOutlet weak var humidityOffsetDate: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tagNameTextField: UITextField!
    
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
}

// MARK: - IBActions
extension TagSettingsTableViewController {
    @IBAction func dismissBarButtonItemAction(_ sender: Any) {
    }
    
    @IBAction func removeThisRuuviTagButtonTouchUpInside(_ sender: Any) {
    }
    
    @IBAction func randomizeBackgroundButtonTouchUpInside(_ sender: Any) {
    }
    
    @IBAction func selectBackgroundButtonTouchUpInside(_ sender: Any) {
    }
}

// MARK: - UITextFieldDelegate
extension TagSettingsTableViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
