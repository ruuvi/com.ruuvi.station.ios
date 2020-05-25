import UIKit

class AdvancedTableViewController: UITableViewController {
    var output: AdvancedViewOutput!

    var viewModels = [AdvancedViewModel]() {
        didSet {
            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }

    private let switchCellReuseIdentifier = "AdvancedSwitchTableViewCellReuseIdentifier"
    private let stepperCellReuseIdentifier = "AdvancedStepperTableViewCellReuseIdentifier"

    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
    }
}

extension AdvancedTableViewController: AdvancedViewInput {
    func localize() {
        title = "Advanced.title".localized()
    }
}

// MARK: - View lifecycle
extension AdvancedTableViewController {

}

// MARK: - UITableViewDataSource
extension AdvancedTableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = viewModels[indexPath.row]
        if let boolean = viewModel.boolean.value {
            // swiftlint:disable force_cast
            let cell = tableView
                .dequeueReusableCell(withIdentifier: switchCellReuseIdentifier,
                                     for: indexPath) as! AdvancedSwitchTableViewCell
            // swiftlint:enable force_cast
            cell.titleLabel.text = viewModel.title
            cell.isOnSwitch.isOn = boolean
            cell.delegate = self
            return cell
        } else {
            // swiftlint:disable force_cast
            let cell = tableView
                .dequeueReusableCell(withIdentifier: stepperCellReuseIdentifier,
                                     for: indexPath) as! AdvancedStepperTableViewCell
            // swiftlint:enable force_cast
            let title = viewModel.title ?? ""
            let unitString: String
            switch viewModel.unit {
            case .hours:
                unitString = "Advanced.Interval.Hour.string".localized()
            case .minutes:
                unitString = "Advanced.Interval.Min.string".localized()
            case .seconds:
                unitString = "Advanced.Interval.Sec.string".localized()
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

// MARK: - AdvancedSwitchTableViewCellDelegate
extension AdvancedTableViewController: AdvancedSwitchTableViewCellDelegate {
    func advancedSwitch(cell: AdvancedSwitchTableViewCell, didChange value: Bool) {
        if let indexPath = tableView.indexPath(for: cell) {
            viewModels[indexPath.row].boolean.value = value
        }
    }
}

// MARK: - AdvancedStepperTableViewCellDelegate
extension AdvancedTableViewController: AdvancedStepperTableViewCellDelegate {
    func advancedStepper(cell: AdvancedStepperTableViewCell, didChange value: Int) {
        if let indexPath = tableView.indexPath(for: cell) {
            viewModels[indexPath.row].integer.value = value
        }
    }
}
