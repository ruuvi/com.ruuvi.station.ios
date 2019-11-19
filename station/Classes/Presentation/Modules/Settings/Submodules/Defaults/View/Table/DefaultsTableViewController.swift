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

    private let switchCellReuseIdentifier = "DefaultsSwitchTableViewCellReuseIdentifier"
    
}

extension DefaultsTableViewController: DefaultsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - View lifecycle
extension DefaultsTableViewController {
    
}

// MARK: - UITableViewDataSource
extension DefaultsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModels.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = viewModels[indexPath.section]
        let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! DefaultsSwitchTableViewCell
        cell.titleLabel.text = viewModel.title
        cell.isOnSwitch.isOn = viewModel.boolean.value.bound
        cell.delegate = self
        return cell
    }
}

// MARK: - DefaultsSwitchTableViewCellDelegate
extension DefaultsTableViewController: DefaultsSwitchTableViewCellDelegate {
    func defaultsSwitch(cell: DefaultsSwitchTableViewCell, didChange value: Bool) {
        if let indexPath = tableView.indexPath(for: cell) {
            viewModels[indexPath.section].boolean.value = value
        }
    }
}

