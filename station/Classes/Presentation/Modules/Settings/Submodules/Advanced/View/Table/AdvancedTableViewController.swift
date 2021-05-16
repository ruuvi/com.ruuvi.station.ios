import UIKit

class AdvancedTableViewController: UITableViewController {
    var output: AdvancedViewOutput!

    var viewModel = AdvancedViewModel(sections: []) {
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
                .dequeueReusableCell(with: AdvancedSwitchTableViewCell.self, for: indexPath)
            cell.titleLabel.text = title
            cell.isOnSwitch.isOn = value
            cell.delegate = self
            return cell
        case .stepper(let title, let value, let unit):
            let cell = tableView
                .dequeueReusableCell(with: AdvancedStepperTableViewCell.self,
                                     for: indexPath)
            let title = title
            cell.unit = unit
            cell.titleLabel.text = title + " "
                + "(" + "\(value)" + " "
                + unit.unitString + ")"
            cell.prefix = title
            cell.stepper.value = Double(value)
            cell.delegate = self
            return cell
        case .disclosure(let title):
            let cell = tableView.dequeueReusableCell(with: AdvancedDisclosureTableViewCell.self, for: indexPath)
            cell.textLabel?.text = title
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.sections[section].title
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - AdvancedSwitchTableViewCellDelegate
extension AdvancedTableViewController: AdvancedSwitchTableViewCellDelegate {
    func advancedSwitch(cell: AdvancedSwitchTableViewCell, didChange value: Bool) {
        if let indexPath = tableView.indexPath(for: cell) {
            let cellViewModel = viewModel.sections[indexPath.section].cells[indexPath.row]
            cellViewModel.boolean.value = value
        }
    }
}

// MARK: - AdvancedStepperTableViewCellDelegate
extension AdvancedTableViewController: AdvancedStepperTableViewCellDelegate {
    func advancedStepper(cell: AdvancedStepperTableViewCell, didChange value: Int) {
        if let indexPath = tableView.indexPath(for: cell) {
            let cellViewModel = viewModel.sections[indexPath.section].cells[indexPath.row]
            cellViewModel.integer.value = value
        }
    }
}
