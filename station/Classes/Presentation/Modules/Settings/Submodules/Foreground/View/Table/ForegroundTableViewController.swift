import UIKit

class ForegroundTableViewController: UITableViewController {
    var output: ForegroundViewOutput!

    var viewModels = [ForegroundViewModel]() {
        didSet {
            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }

    private let switchCellReuseIdentifier = "ForegroundSwitchTableViewCellReuseIdentifier"
    private let stepperCellReuseIdentifier = "ForegroundStepperTableViewCellReuseIdentifier"
}

// MARK: - ForegroundViewInput
extension ForegroundTableViewController: ForegroundViewInput {
    func apply(theme: Theme) {

    }

    func localize() {

    }
}

// MARK: - View lifecycle
extension ForegroundTableViewController {

}

// MARK: - UITableViewDataSource
extension ForegroundTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModels.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = viewModels[indexPath.section]
        if indexPath.row == 0 {
            // swiftlint:disable force_cast
            let cell = tableView
                .dequeueReusableCell(withIdentifier: switchCellReuseIdentifier,
                                     for: indexPath) as! ForegroundSwitchTableViewCell
            // swiftlint:enable force_cast
            cell.titleLabel.text = viewModel.title
            cell.isOnSwitch.isOn = viewModel.isOn.value.bound
            cell.delegate = self
            return cell
        } else {
            // swiftlint:disable force_cast
            let cell = tableView
                .dequeueReusableCell(withIdentifier: stepperCellReuseIdentifier,
                                     for: indexPath) as! ForegroundStepperTableViewCell
            // swiftlint:enable force_cast
            if viewModel.interval.value.bound > 0 {
                cell.titleLabel.text = "Foreground.Interval.Every.string".localized()
                    + " " + "\(viewModel.interval.value.bound)"
                    + " " + "Foreground.Interval.Min.string".localized()
            } else {
                cell.titleLabel.text = "Foreground.Interval.All.string".localized()
            }
            cell.stepper.value = Double(viewModel.interval.value.bound)
            cell.stepper.minimumValue = Double(viewModel.minValue.value.bound)
            cell.stepper.maximumValue = Double(viewModel.maxValue.value.bound)
            cell.delegate = self
            return cell
        }
    }
}

// MARK: - ForegroundSwitchTableViewCellDelegate
extension ForegroundTableViewController: ForegroundSwitchTableViewCellDelegate {
    func foregroundSwitch(cell: ForegroundSwitchTableViewCell, didChange value: Bool) {
        if let indexPath = tableView.indexPath(for: cell) {
            viewModels[indexPath.section].isOn.value = value
        }
    }
}

// MARK: - ForegroundStepperTableViewCellDelegate
extension ForegroundTableViewController: ForegroundStepperTableViewCellDelegate {
    func foregroundStepper(cell: ForegroundStepperTableViewCell, didChange value: Int) {
        if let indexPath = tableView.indexPath(for: cell) {
            viewModels[indexPath.section].interval.value = value
        }
    }
}
