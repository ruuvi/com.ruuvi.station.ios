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
    private let stepperCellReuseIdentifier = "DefaultsStepperTableViewCellReuseIdentifier"
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = viewModels[indexPath.row]
        if let boolean = viewModel.boolean.value {
            // swiftlint:disable force_cast
            let cell = tableView
                .dequeueReusableCell(withIdentifier: switchCellReuseIdentifier,
                                     for: indexPath) as! DefaultsSwitchTableViewCell
            // swiftlint:enable force_cast
            cell.titleLabel.text = viewModel.title
            cell.isOnSwitch.isOn = boolean
            cell.delegate = self
            return cell
        } else {
            // swiftlint:disable force_cast
            let cell = tableView
                .dequeueReusableCell(withIdentifier: stepperCellReuseIdentifier,
                                     for: indexPath) as! DefaultsStepperTableViewCell
            // swiftlint:enable force_cast
            let title = viewModel.title ?? ""
            let unitString: String
            switch viewModel.unit {
            case .minutes:
                unitString = "Defaults.Interval.Min.string".localized()
            case .seconds:
                unitString = "Defaults.Interval.Sec.string".localized()
            }
            cell.unit = viewModel.unit
            cell.titleLabel.text = title + " "
                + "(" + "\(viewModel.integer.value.bound)" + " "
                + unitString + ")"
            cell.prefix = title
            cell.stepper.value = Double(viewModel.integer.value.bound)
            cell.delegate = self
            return cell
        }

    }
}

// MARK: - DefaultsSwitchTableViewCellDelegate
extension DefaultsTableViewController: DefaultsSwitchTableViewCellDelegate {
    func defaultsSwitch(cell: DefaultsSwitchTableViewCell, didChange value: Bool) {
        if let indexPath = tableView.indexPath(for: cell) {
            viewModels[indexPath.row].boolean.value = value
        }
    }
}

// MARK: - DefaultsStepperTableViewCellDelegate
extension DefaultsTableViewController: DefaultsStepperTableViewCellDelegate {
    func defaultsStepper(cell: DefaultsStepperTableViewCell, didChange value: Int) {
        if let indexPath = tableView.indexPath(for: cell) {
            viewModels[indexPath.row].integer.value = value
        }
    }
}
