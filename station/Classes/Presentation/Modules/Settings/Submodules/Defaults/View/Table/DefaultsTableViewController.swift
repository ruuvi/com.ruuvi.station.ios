import UIKit

class DefaultsTableViewController: UITableViewController {
    var output: DefaultsViewOutput!
    
    var viewModels = [DefaultsViewModel]() {
        didSet {
            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }

}

extension DefaultsTableViewController: DefaultsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}
