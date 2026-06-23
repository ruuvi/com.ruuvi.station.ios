// swiftlint:disable file_length
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import UIKit

class UnitSettingsTableViewController: UITableViewController {
    var output: UnitSettingsViewOutput!
    var settings: RuuviLocalSettings!

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
    private var configuredHeaderMode: UnitSettingsMode?
    private var configuredHeaderWidth: CGFloat = 0
}

// MARK: - SelectionViewInput

extension UnitSettingsTableViewController: UnitSettingsViewInput {
    func localize() {
        tableView.reloadData()
    }

    func reloadSettings() {
        tableView.reloadData()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
    }
}

// MARK: - View lifecycle

extension UnitSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        styleViews()
        output.viewDidLoad()
        updateUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureHeaderIfNeeded()
    }
}

// MARK: - UITableViewDataSource

extension UnitSettingsTableViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard let measurementType = viewModel?.measurementType else {
            return 2
        }

        switch viewModel?.mode {
        case .globalUnits:
            return groupedMeasurementTypes.count
        case .resolution:
            return resolutionTargets.count
        default:
            if measurementType == .pressure,
               !pressureUnit.supportsResolutionSelection {
                return 1
            }
            return 2
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: unitSettingsCellReuseIdentifier,
            for: indexPath
        ) as? UnitSettingsTableViewCell
        else {
            return .init()
        }

        cell.titleLbl.font = .ruuviHeadline()
        cell.valueLbl.font = .ruuviBody()
        cell.selectionStyle = .default
        cell.isUserInteractionEnabled = true

        switch viewModel?.mode {
        case .globalUnits:
            configureGroupedUnitsCell(cell, at: indexPath.row)
        case .resolution:
            configureResolutionCell(cell, at: indexPath.row)
        default:
            configureMeasurementCell(cell, at: indexPath.row)
        }

        let enabled = isRowEnabled(at: indexPath)
        let textColor = RuuviColor.menuTextColor.color.withAlphaComponent(enabled ? 1 : 0.4)
        cell.titleLbl.textColor = textColor
        cell.valueLbl.textColor = textColor
        cell.selectionStyle = enabled ? .default : .none
        cell.isUserInteractionEnabled = enabled
        return cell
    }
}

// MARK: - Cell configuration

private extension UnitSettingsTableViewController {
    var groupedMeasurementTypes: [MeasurementType] {
        [.temperature, .humidity, .pressure]
    }

    var resolutionTargets: [ResolutionSettingsTarget] {
        viewModel?.items.compactMap { $0 as? ResolutionSettingsTarget } ?? []
    }

    // swiftlint:disable:next cyclomatic_complexity
    func configureMeasurementCell(
        _ cell: UnitSettingsTableViewCell,
        at row: Int
    ) {
        if row == 0 {
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
                ) + " \(pressureUnit.ruuviSymbol)"
            default:
                cell.valueLbl.text = RuuviLocalization.na
            }
        }
    }

    func configureGroupedUnitsCell(
        _ cell: UnitSettingsTableViewCell,
        at row: Int
    ) {
        guard groupedMeasurementTypes.indices.contains(row) else {
            cell.titleLbl.text = RuuviLocalization.na
            cell.valueLbl.text = nil
            return
        }

        let measurementType = groupedMeasurementTypes[row]
        cell.titleLbl.text = title(for: measurementType)
        cell.valueLbl.text = unitValue(for: measurementType)
    }

    func configureResolutionCell(
        _ cell: UnitSettingsTableViewCell,
        at row: Int
    ) {
        guard resolutionTargets.indices.contains(row) else {
            cell.titleLbl.text = RuuviLocalization.na
            cell.valueLbl.text = nil
            return
        }

        let target = resolutionTargets[row]
        cell.titleLbl.text = target.title("")
        cell.valueLbl.text = resolutionValue(for: target)
    }

    func title(for measurementType: MeasurementType) -> String {
        switch measurementType {
        case .temperature:
            return RuuviLocalization.temperature
        case .humidity:
            return RuuviLocalization.humidity
        case .pressure:
            return RuuviLocalization.pressure
        default:
            return RuuviLocalization.na
        }
    }

    func unitValue(for measurementType: MeasurementType) -> String {
        switch measurementType {
        case .temperature:
            return temperatureUnit.title("")
        case .humidity:
            return humidityUnit == .dew
                ? humidityUnit.title(temperatureUnit.symbol)
                : humidityUnit.title("")
        case .pressure:
            return pressureUnit.title("")
        default:
            return RuuviLocalization.na
        }
    }

    func resolutionValue(for measurementType: MeasurementType) -> String {
        let titleProvider = MeasurementAccuracyTitles()
        switch measurementType {
        case .temperature:
            return titleProvider.formattedTitle(
                type: temperatureAccuracy,
                settings: settings
            ) + " \(temperatureUnit.symbol)"
        case .humidity:
            let unitSymbol = humidityUnit == .dew
                ? temperatureUnit.symbol
                : humidityUnit.symbol
            return titleProvider.formattedTitle(
                type: humidityAccuracy,
                settings: settings
            ) + " \(unitSymbol)"
        case .pressure:
            let accuracy: MeasurementAccuracyType = pressureUnit.supportsResolutionSelection
                ? pressureAccuracy
                : .zero
            return titleProvider.formattedTitle(
                type: accuracy,
                settings: settings
            ) + " \(pressureUnit.ruuviSymbol)"
        default:
            return RuuviLocalization.na
        }
    }

    func resolutionValue(for target: ResolutionSettingsTarget) -> String {
        let titleProvider = MeasurementAccuracyTitles()
        return titleProvider.formattedTitle(
            type: accuracy(for: target),
            settings: settings
        ) + " \(unit(for: target))"
    }

    func accuracy(for target: ResolutionSettingsTarget) -> MeasurementAccuracyType {
        target.accuracy(
            settings: settings,
            pressureUnit: pressureUnit
        )
    }

    func unit(for target: ResolutionSettingsTarget) -> String {
        target.unitSymbol(
            temperatureUnit: temperatureUnit,
            pressureUnit: pressureUnit
        )
    }

    func isRowEnabled(at indexPath: IndexPath) -> Bool {
        guard viewModel?.mode == .resolution
        else {
            return true
        }
        guard resolutionTargets.indices.contains(indexPath.row),
              resolutionTargets[indexPath.row] == .pressure else {
            return true
        }
        return pressureUnit.supportsResolutionSelection
    }
}

// MARK: - UITableViewDelegate

extension UnitSettingsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard isRowEnabled(at: indexPath) else {
            return
        }
        if indexPath.row == 1,
           viewModel?.measurementType == .pressure,
           viewModel?.mode == .measurement,
           !pressureUnit.supportsResolutionSelection {
            return
        }
        output.viewDidSelect(row: indexPath.row)
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        isRowEnabled(at: indexPath) ? indexPath : nil
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}

// MARK: - Update UI

extension UnitSettingsTableViewController {
    private func updateUI() {
        title = viewModel?.title
        if isViewLoaded {
            configureHeaderIfNeeded(force: true)
            tableView.reloadData()
        }
    }

    private func configureHeaderIfNeeded(force: Bool = false) {
        let mode = viewModel?.mode
        let width = tableView.bounds.width
        guard force
            || configuredHeaderMode != mode
            || configuredHeaderWidth != width else {
            return
        }

        configuredHeaderMode = mode
        configuredHeaderWidth = width
        configureHeader()
    }

    private func configureHeader() {
        guard let description = headerDescription() else {
            tableView.tableHeaderView = UIView()
            return
        }

        let horizontalPadding: CGFloat = 20
        let verticalPadding: CGFloat = 16
        let label = UILabel()
        label.font = UIFont.ruuviFootnote()
        label.textColor = RuuviColor.textColor.color.withAlphaComponent(0.6)
        label.numberOfLines = 0
        label.text = description

        let width = tableView.bounds.width - horizontalPadding * 2
        let size = label.sizeThatFits(
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
        let container = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: tableView.bounds.width,
                height: size.height + verticalPadding * 2
            )
        )
        label.frame = CGRect(
            x: horizontalPadding,
            y: verticalPadding,
            width: width,
            height: size.height
        )
        container.addSubview(label)
        tableView.tableHeaderView = container
    }

    private func headerDescription() -> String? {
        switch viewModel?.mode {
        case .globalUnits:
            return RuuviLocalization.Settings.GlobalUnits.description
        case .resolution:
            return RuuviLocalization.Settings.Measurement.Resolution.description
        default:
            return nil
        }
    }
}
