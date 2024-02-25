import RuuviLocalization
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
        tableView.sectionFooterHeight = UITableView.automaticDimension
        localize()
        styleViews()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }
}

extension ChartSettingsTableViewController: ChartSettingsViewInput {
    func localize() {
        title = RuuviLocalization.Settings.Label.chart
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
    }
}

// MARK: - View lifecycle

extension ChartSettingsTableViewController {}

// MARK: - UITableViewDataSource

extension ChartSettingsTableViewController {
    override func numberOfSections(in _: UITableView) -> Int {
        viewModel.sections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellViewModel = viewModel.sections[indexPath.section].cells[indexPath.row]

        switch cellViewModel.type {
        case let .switcher(title, value, hideStatusLabel):
            let cell = tableView
                .dequeueReusableCell(with: ChartSettingsSwitchTableViewCell.self, for: indexPath)
            cell.titleLabel.text = title
            cell.titleLabel.textColor = RuuviColor.menuTextColor.color
            cell.isOnSwitch.toggleState(with: value)
            cell.isOnSwitch.hideStatusLabel(hide: hideStatusLabel)
            cell.delegate = self
            return cell
        case let .stepper(title, value, unitSingular, unitPlural):
            let cell = tableView
                .dequeueReusableCell(
                    with: ChartSettingsStepperTableViewCell.self,
                    for: indexPath
                )
            let title = title
            let unit = value > 1 ? unitPlural : unitSingular
            cell.titleLabel.text = title + " "
                + "(" + "\(value)" + " "
                + unit.unitString + ")"
            cell.titleLabel.textColor = RuuviColor.menuTextColor.color
            cell.prefix = title
            cell.stepper.value = Double(value)
            cell.stepper.backgroundColor = RuuviColor.tintColor.color
            cell.delegate = self
            return cell
        case let .disclosure(title):
            let cell = tableView.dequeueReusableCell(with: ChartSettingsDisclosureTableViewCell.self, for: indexPath)
            cell.textLabel?.text = title
            cell.textLabel?.textColor = RuuviColor.menuTextColor.color
            return cell
        }
    }

    override func tableView(_: UITableView, estimatedHeightForFooterInSection _: Int) -> CGFloat {
        100
    }

    override func tableView(_: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        let footerLabel = UILabel()
        footerLabel.textColor = RuuviColor.textColor.color.withAlphaComponent(0.6)
        footerLabel.font = UIFont.Muli(.regular, size: 13)
        footerLabel.numberOfLines = 0
        footerLabel.text = viewModel.sections[section].note
        footerView.addSubview(footerLabel)
        footerLabel.fillSuperview(padding: .init(top: 8, left: 20, bottom: 8, right: 20))
        return footerView
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
