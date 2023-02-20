import UIKit
import RuuviOntology
import RuuviLocal

class SelectionTableViewController: UITableViewController {
    var output: SelectionViewOutput!
    var settings: RuuviLocalSettings!
    @IBOutlet weak var descriptionTextView: UITextView!

    var viewModel: SelectionViewModel? {
        didSet {
            updateUI()
        }
    }

    var temperatureUnit: TemperatureUnit = .celsius {
        didSet {
            tableView.reloadData()
        }
    }

    var humidityUnit: HumidityUnit = .percent {
        didSet {
            tableView.reloadData()
        }
    }

    var pressureUnit: UnitPressure = .hectopascals {
        didSet {
            tableView.reloadData()
        }
    }

    private let cellReuseIdentifier = "SelectionTableViewCellReuseIdentifier"
}

// MARK: - SelectionViewInput
extension SelectionTableViewController: SelectionViewInput {
    func localize() {
        tableView.reloadData()
    }
}

// MARK: - View lifecycle
extension SelectionTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        output.viewDidLoad()
        updateUI()
        setupLocalization()
    }
}

// MARK: - UITableViewDataSource
extension SelectionTableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.items.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = viewModel?.items[indexPath.row],
              let cell = tableView
                .dequeueReusableCell(withIdentifier: cellReuseIdentifier,
                                     for: indexPath) as? SelectionTableViewCell else {
            return .init()
        }

        if viewModel?.unitSettingsType == .accuracy,
            let item = item as? MeasurementAccuracyType {
            let titleProvider = MeasurementAccuracyTitles()
            let title = titleProvider.formattedTitle(type: item, settings: settings)
            switch viewModel?.measurementType {
            case .temperature:
                cell.nameLabel.text = title + " " + temperatureUnit.symbol
            case .humidity:
                if humidityUnit == .dew {
                    cell.nameLabel.text = title + " " + temperatureUnit.symbol
                } else {
                    cell.nameLabel.text = title + " " + humidityUnit.symbol
                }
            case .pressure:
                cell.nameLabel.text = title + " " + pressureUnit.symbol
            default:
                cell.nameLabel.text = "N/A".localized()
            }
            updateCellStyle(with: title, cell: cell)

        } else {
            if let humidityUnit = item as? HumidityUnit, humidityUnit == .dew {
                cell.nameLabel.text = String(format: item.title, settings.temperatureUnit.symbol)
            } else {
                cell.nameLabel.text = item.title
            }
            updateCellStyle(with: item.title, cell: cell)
        }

        return cell
    }
}

// MARK: - UITableViewDelegate
extension SelectionTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        output.viewDidSelect(itemAtIndex: indexPath.row)
    }
}

// MARK: - Update UI
extension SelectionTableViewController {
    private func updateUI() {
        title = viewModel?.title
        if isViewLoaded {
            descriptionTextView.text = viewModel?.description
        }
        updateUISelections()
    }

    private func updateUISelections() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }

    private func updateCellStyle(with title: String?,
                                 cell: SelectionTableViewCell) {
        if title == viewModel?.selection {
            cell.accessoryType = .checkmark
            cell.nameLabel.textColor = RuuviColor.ruuviMenuTextColor
            cell.nameLabel.font = UIFont.Muli(.bold, size: 16)
        } else {
            cell.accessoryType = .none
            cell.nameLabel.textColor = RuuviColor.ruuviTextColor
            cell.nameLabel.font = UIFont.Muli(.regular, size: 16)
        }
    }
}
