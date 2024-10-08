import RuuviLocalization
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
    private let plainCellReuseIdentifier = "DefaultsPlainTableViewCellReuseIdentifier"
}

extension DefaultsTableViewController: DefaultsViewInput {
    func localize() {
        // do nothing
    }

    func showEndpointChangeConfirmationDialog(useDevServer _: Bool?) {
        // No op.
    }
}

// MARK: - View lifecycle

extension DefaultsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        styleViews()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
    }
}

// MARK: - UITableViewDataSource

extension DefaultsTableViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = viewModels[indexPath.row]
        switch viewModel.type.value {
        case .plain:
            // swiftlint:disable force_cast
            let cell = tableView
                .dequeueReusableCell(
                    withIdentifier: plainCellReuseIdentifier,
                    for: indexPath
                ) as! DefaultsPlainTableViewCell
            // swiftlint:enable force_cast
            cell.titleLabel.text = viewModel.title
            cell.titleLabel.textColor = RuuviColor.menuTextColor.color
            cell.valueLabel.text = viewModel.value.value ?? RuuviLocalization.na
            cell.valueLabel.textColor = RuuviColor.menuTextColor.color
            return cell
        case .switcher:
            // swiftlint:disable force_cast
            let cell = tableView
                .dequeueReusableCell(
                    withIdentifier: switchCellReuseIdentifier,
                    for: indexPath
                ) as! DefaultsSwitchTableViewCell
            // swiftlint:enable force_cast
            cell.titleLabel.text = viewModel.title
            cell.titleLabel.textColor = RuuviColor.menuTextColor.color
            cell.isOnSwitch.toggleState(with: viewModel.boolean.value ?? false)
            cell.isOnSwitch.hideStatusLabel(hide: viewModel.hideStatusLabel.value ?? false)
            cell.delegate = self
            return cell
        case .stepper:
            // swiftlint:disable force_cast
            let cell = tableView
                .dequeueReusableCell(
                    withIdentifier: stepperCellReuseIdentifier,
                    for: indexPath
                ) as! DefaultsStepperTableViewCell
            // swiftlint:enable force_cast
            let title = viewModel.title ?? ""

            cell.unit = viewModel.unit
            cell.item = viewModel.item.value
            let result = viewModel.integer.value.bound
            switch viewModel.item.value {
            case .imageCompressionQuality:
                cell.titleLabel.text = title + " " + "(" + "\(result)" + "%)"
                cell.stepper.stepValue = 10
                cell.stepper.minimumValue = 10
                cell.stepper.maximumValue = 100
                cell.stepper.value = Double(viewModel.integer.value.bound)
            default:
                let unitString: String
                switch viewModel.unit {
                case .hours:
                    unitString = RuuviLocalization.Defaults.Interval.Hour.string
                    cell.stepper.stepValue = 1
                case .minutes:
                    unitString = RuuviLocalization.Defaults.Interval.Min.string
                    cell.stepper.stepValue = 5
                case .seconds:
                    unitString = RuuviLocalization.Defaults.Interval.Sec.string
                    cell.stepper.stepValue = 30
                case .decimal:
                    unitString = ""
                    cell.stepper.stepValue = 5
                    cell.stepper.minimumValue = 5
                }
                switch viewModel.unit {
                case .hours, .minutes, .seconds:
                    cell.titleLabel.text = title + " "
                        + "(" + "\(result)" + " "
                        + unitString + ")"
                case .decimal:
                    cell.titleLabel.text = title + " " + "(" + "\(result)" + ")"
                }
                cell.stepper.value = Double(viewModel.integer.value.bound)
            }

            cell.titleLabel.textColor = RuuviColor.menuTextColor.color
            cell.stepper.backgroundColor = RuuviColor.tintColor.color
            cell.prefix = title
            cell.delegate = self
            return cell
        default:
            // Should never be here
            return UITableViewCell()
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
