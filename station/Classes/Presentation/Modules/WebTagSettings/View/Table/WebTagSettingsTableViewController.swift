import UIKit

class WebTagSettingsTableViewController: UITableViewController {
    var output: WebTagSettingsViewOutput!
}

// MARK: - WebTagSettingsViewInput
extension WebTagSettingsTableViewController: WebTagSettingsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - IBActions
extension WebTagSettingsTableViewController {
    @IBAction func dismissBarButtonItemAction(_ sender: Any) {
        output.viewDidAskToDismiss()
    }
}
