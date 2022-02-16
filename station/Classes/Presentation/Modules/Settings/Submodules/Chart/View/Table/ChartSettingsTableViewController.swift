import UIKit

class ChartSettingsTableViewController: UITableViewController {
    var output: ChartSettingsViewOutput!

    var viewModel = ChartSettingsViewModel(sections: []) {
        didSet {
            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }
}

extension ChartSettingsTableViewController: ChartSettingsViewInput {
    func localize() {
        title = "Settings.Label.Chart".localized()
    }
}

// MARK: - View lifecycle
extension ChartSettingsTableViewController {

}

// MARK: - UITableViewDataSource
extension ChartSettingsTableViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellViewModel = viewModel.sections[indexPath.section].cells[indexPath.row]

        switch cellViewModel.type {
        case .switcher(let title, let value):
            let cell = tableView
                .dequeueReusableCell(with: ChartSettingsSwitchTableViewCell.self, for: indexPath)
            cell.titleLabel.text = title
            cell.isOnSwitch.isOn = value
            cell.delegate = self
            return cell
        case .stepper(let title, let value, let unitSingular, let unitPlural):
            let cell = tableView
                .dequeueReusableCell(with: ChartSettingsStepperTableViewCell.self,
                                     for: indexPath)
            let title = title
            let unit = value > 1 ? unitPlural : unitSingular
            cell.titleLabel.text = title + " "
                + "(" + "\(value)" + " "
            + unit.unitString + ")"
            cell.prefix = title
            cell.stepper.value = Double(value)
            cell.delegate = self
            return cell
        case .disclosure(let title):
            let cell = tableView.dequeueReusableCell(with: ChartSettingsDisclosureTableViewCell.self, for: indexPath)
            cell.textLabel?.text = title
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return viewModel.sections[section].note
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - AdvancedSwitchTableViewCellDelegate
extension ChartSettingsTableViewController: ChartSettingsSwitchTableViewCellDelegate {
    func chartSettingsSwitch(cell: ChartSettingsSwitchTableViewCell, didChange value: Bool) {
        if let indexPath = tableView.indexPath(for: cell) {
            let cellViewModel = viewModel.sections[indexPath.section].cells[indexPath.row]
            cellViewModel.boolean.value = value
        }
    }
}

// MARK: - AdvancedStepperTableViewCellDelegate
extension ChartSettingsTableViewController: ChartSettingsStepperTableViewCellDelegate {
    func chartSettingsStepper(cell: ChartSettingsStepperTableViewCell, didChange value: Int) {
        if let indexPath = tableView.indexPath(for: cell) {
            let cellViewModel = viewModel.sections[indexPath.section].cells[indexPath.row]
            cellViewModel.integer.value = value
        }
    }
}
