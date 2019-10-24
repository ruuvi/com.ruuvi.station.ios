import UIKit

enum BackgroundTableSectionRows: Int, CaseIterable {
    case keepConnection = 0
    case presentNotifications = 1
    case syncLogs = 2
    case saveHeartbeats = 3
    case saveHeartbeatsInterval = 4
}

class BackgroundTableViewController: UITableViewController {
    var output: BackgroundViewOutput!
    
    var viewModels = [BackgroundViewModel]() {
        didSet {
            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }
    
    private let switchCellReuseIdentifier = "BackgroundSwitchTableViewCellReuseIdentifier"
    private let stepperCellReuseIdentifier = "BackgroundStepperTableViewCellReuseIdentifier"
}

// MARK: - BackgroundViewInput
extension BackgroundTableViewController: BackgroundViewInput {
    func apply(theme: Theme) {
        
    }
    
    func localize() {
        
    }
}

// MARK: - View lifecycle
extension BackgroundTableViewController {
    
}

// MARK: - UITableViewDelegate
extension BackgroundTableViewController {
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModels[section].name.value
    }
}

// MARK: - UITableViewDataSource
extension BackgroundTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModels.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return BackgroundTableSectionRows.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = viewModels[indexPath.section]
        let type = BackgroundTableSectionRows(rawValue: indexPath.row) ?? .keepConnection
        switch type {
        case .keepConnection:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! BackgroundSwitchTableViewCell
            cell.titleLabel.text = viewModel.keepConnectionTitle
            cell.isOnSwitch.isOn = viewModel.keepConnection.value.bound
            cell.delegate = self
            return cell
        case .presentNotifications:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! BackgroundSwitchTableViewCell
            cell.titleLabel.text = viewModel.presentNotificationsTitle
            cell.isOnSwitch.isOn = viewModel.presentConnectionNotifications.value.bound
            cell.delegate = self
            return cell
        case .syncLogs:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! BackgroundSwitchTableViewCell
            cell.titleLabel.text = viewModel.syncLogsOnDidConnectTitle
            cell.isOnSwitch.isOn = viewModel.syncLogsOnDidConnect.value.bound
            cell.delegate = self
            return cell
        case .saveHeartbeats:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! BackgroundSwitchTableViewCell
            cell.titleLabel.text = viewModel.saveHeartbeatsTitle
            cell.isOnSwitch.isOn = viewModel.saveHeartbeats.value.bound
            cell.delegate = self
            return cell
        case .saveHeartbeatsInterval:
            let cell = tableView.dequeueReusableCell(withIdentifier: stepperCellReuseIdentifier, for: indexPath) as! BackgroundStepperTableViewCell
            cell.titleLabel.text = "Background.Interval.Every.string".localized() + " " + "\(viewModel.saveHeartbeatsInterval.value.bound)" + " " + "Background.Interval.Min.string".localized()
            cell.stepper.value = Double(viewModel.saveHeartbeatsInterval.value.bound)
            cell.delegate = self
            return cell
        }
    }
}

// MARK: - BackgroundSwitchTableViewCellDelegate
extension BackgroundTableViewController: BackgroundSwitchTableViewCellDelegate {
    func backgroundSwitch(cell: BackgroundSwitchTableViewCell, didChange value: Bool) {
        if let indexPath = tableView.indexPath(for: cell),
            let type = BackgroundTableSectionRows(rawValue: indexPath.row) {
            switch type {
            case .keepConnection:
                viewModels[indexPath.section].keepConnection.value = value
            case .presentNotifications:
                viewModels[indexPath.section].presentConnectionNotifications.value = value
            case .syncLogs:
                viewModels[indexPath.section].syncLogsOnDidConnect.value = value
            case .saveHeartbeats:
                viewModels[indexPath.section].saveHeartbeats.value = value
            case .saveHeartbeatsInterval:
                break // do nothing, unreachable
            }
            
        }
    }
}

// MARK: - BackgroundStepperTableViewCellDelegate
extension BackgroundTableViewController: BackgroundStepperTableViewCellDelegate {
    func backgroundStepper(cell: BackgroundStepperTableViewCell, didChange value: Int) {
        if let indexPath = tableView.indexPath(for: cell),
            let type = BackgroundTableSectionRows(rawValue: indexPath.row) {
            switch type {
            case .saveHeartbeatsInterval:
                viewModels[indexPath.section].saveHeartbeatsInterval.value = value
            default:
                break // do nothing
            }
            
        }
    }
}
