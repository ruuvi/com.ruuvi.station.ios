import UIKit

class TagSettingsTableViewController: UITableViewController {
    var output: TagSettingsViewOutput!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
}

extension TagSettingsTableViewController: TagSettingsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}
