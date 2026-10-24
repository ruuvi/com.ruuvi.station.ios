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
            cell.titleLabel.font = UIFont.ruuviHeadline()
            cell.titleLabel.textColor = RuuviColor.menuTextColor.color
            cell.valueLabel.text = viewModel.value.value ?? RuuviLocalization.na
            cell.valueLabel.textColor = RuuviColor.menuTextColor.color
            cell.valueLabel.font = UIFont.ruuviSubheadline()
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
            cell.titleLabel.font = UIFont.ruuviHeadline()
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
            cell.configure(with: viewModel)
            cell.delegate = self
            return cell
        default:
            // Should never be here
            return UITableViewCell()
        }
    }
}

// MARK: - Interval presets and direct entry

extension DefaultsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let viewModel = viewModels[indexPath.row]
        guard let configuration = viewModel.integerEditor else { return }
        DefaultsIntegerEditor.present(
            from: self,
            title: viewModel.title,
            value: viewModel.integer.value.bound,
            configuration: configuration
        ) { [weak self] value in
            viewModel.integer.value = value
            self?.tableView.reloadData()
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
