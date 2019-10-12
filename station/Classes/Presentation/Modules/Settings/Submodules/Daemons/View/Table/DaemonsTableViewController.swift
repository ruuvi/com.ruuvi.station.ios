import UIKit

class DaemonsTableViewController: UITableViewController {
    var output: DaemonsViewOutput!
    
    var viewModels = [DaemonsViewModel]()
    
    private let switchCellReuseIdentifier = "DaemonsSwitchTableViewCellReuseIdentifier"
    private let stepperCellReuseIdentifier = "DaemonsStepperTableViewCellReuseIdentifier"
}

// MARK: - DaemonsViewInput
extension DaemonsTableViewController: DaemonsViewInput {
    func apply(theme: Theme) {
        
    }
    
    func localize() {
        
    }
}

// MARK: - View lifecycle
extension DaemonsTableViewController {
    
}

// MARK: - UITableViewDataSource
extension DaemonsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModels.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = viewModels[indexPath.section]
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! DaemonsSwitchTableViewCell
            cell.titleLabel.text = viewModel.title
            cell.isOnSwitch.isOn = viewModel.isOn.value.bound
            cell.delegate = self
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: stepperCellReuseIdentifier, for: indexPath) as! DaemonsStepperTableViewCell
            cell.titleLabel.text = "Daemons.Interval.Every.string".localized() + " " + "\(viewModel.interval.value.bound)" + " " + "Daemons.Interval.Min.string".localized()
            cell.stepper.value = Double(viewModel.interval.value.bound)
            cell.delegate = self
            return cell
        }
    }
}

// MARK: - DaemonsSwitchTableViewCellDelegate
extension DaemonsTableViewController: DaemonsSwitchTableViewCellDelegate {
    func daemonsSwitch(cell: DaemonsSwitchTableViewCell, didChange value: Bool) {
        if let indexPath = tableView.indexPath(for: cell) {
            viewModels[indexPath.section].isOn.value = value
        }
    }
}

// MARK: - DaemonsStepperTableViewCellDelegate
extension DaemonsTableViewController: DaemonsStepperTableViewCellDelegate {
    func daemonsStepper(cell: DaemonsStepperTableViewCell, didChange value: Int) {
        if let indexPath = tableView.indexPath(for: cell) {
            viewModels[indexPath.section].interval.value = value
        }
    }
}
