import RuuviLocal
import RuuviLocalization
import RuuviOntology
import UIKit

class UnitSettingsTableViewController: UITableViewController {
    var output: UnitSettingsViewOutput!
    var settings: RuuviLocalSettings!

    @IBOutlet var descriptionTextView: UITextView!

    var viewModel: UnitSettingsViewModel? {
        didSet {
            updateUI()
        }
    }

    var temperatureUnit: TemperatureUnit = .celsius {
        didSet {
            tableView.reloadData()
        }
    }

    var temperatureAccuracy: MeasurementAccuracyType = .two {
        didSet {
            tableView.reloadData()
        }
    }

    var humidityUnit: HumidityUnit = .percent {
        didSet {
            tableView.reloadData()
        }
    }

    var humidityAccuracy: MeasurementAccuracyType = .two {
        didSet {
            tableView.reloadData()
        }
    }

    var pressureUnit: UnitPressure = .hectopascals {
        didSet {
            tableView.reloadData()
        }
    }

    var pressureAccuracy: MeasurementAccuracyType = .two {
        didSet {
            tableView.reloadData()
        }
    }

    private let unitSettingsCellReuseIdentifier = "unitSettingsCellReuseIdentifier"
}

// MARK: - SelectionViewInput

extension UnitSettingsTableViewController: UnitSettingsViewInput {
    func localize() {
        tableView.reloadData()
    }
}

// MARK: - View lifecycle

extension UnitSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        output.viewDidLoad()
        updateUI()
    }
}

// MARK: - UITableViewDataSource

extension UnitSettingsTableViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        2
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: unitSettingsCellReuseIdentifier,
            for: indexPath
        ) as? UnitSettingsTableViewCell
        else {
            return .init()
        }

        if indexPath.row == 0 {
            cell.titleLbl.text = RuuviLocalization.Settings.Measurement.Unit.title
            switch viewModel?.measurementType {
            case .temperature:
                cell.valueLbl.text = temperatureUnit.title("")
            case .humidity:
                if humidityUnit == .dew {
                    cell.valueLbl.text = humidityUnit.title(temperatureUnit.symbol)
                } else {
                    cell.valueLbl.text = humidityUnit.title("")
                }
            case .pressure:
                cell.valueLbl.text = pressureUnit.title("")
            default:
                cell.valueLbl.text = RuuviLocalization.na
            }
        } else {
            cell.titleLbl.text = RuuviLocalization.Settings.Measurement.Resolution.title
            let titleProvider = MeasurementAccuracyTitles()
            switch viewModel?.measurementType {
            case .temperature:
                cell.valueLbl.text = titleProvider.formattedTitle(
                    type: temperatureAccuracy,
                    settings: settings
                ) + " \(temperatureUnit.symbol)"
            case .humidity:
                if humidityUnit == .dew {
                    cell.valueLbl.text = titleProvider.formattedTitle(
                        type: humidityAccuracy,
                        settings: settings
                    ) + " \(temperatureUnit.symbol)"
                } else {
                    cell.valueLbl.text = titleProvider.formattedTitle(
                        type: humidityAccuracy,
                        settings: settings
                    ) + " \(humidityUnit.symbol)"
                }
            case .pressure:
                cell.valueLbl.text = titleProvider.formattedTitle(
                    type: pressureAccuracy,
                    settings: settings
                ) + " \(pressureUnit.symbol)"
            default:
                cell.valueLbl.text = RuuviLocalization.na
            }
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension UnitSettingsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        output.viewDidSelect(type: indexPath.row == 0 ? .unit : .accuracy)
    }
}

// MARK: - Update UI

extension UnitSettingsTableViewController {
    private func updateUI() {
        title = viewModel?.title
    }
}
