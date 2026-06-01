import Foundation
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService

class UnitSettingsPresenter {
    weak var view: UnitSettingsViewInput!
    var router: UnitSettingsRouterInput!
    var settings: RuuviLocalSettings!
    var ruuviAppSettingsService: RuuviServiceAppSettings!

    private var temperatureUnitToken: NSObjectProtocol?
    private var temperatureAccuracyToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var humidityAccuracyToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var pressureAccuracyToken: NSObjectProtocol?
    private var pendingSelectionMeasurementType: MeasurementType?

    private var viewModel: UnitSettingsViewModel? {
        didSet {
            view.viewModel = viewModel
        }
    }

    var output: UnitSettingsModuleOutput?

    deinit {
        temperatureUnitToken?.invalidate()
        temperatureAccuracyToken?.invalidate()
        humidityUnitToken?.invalidate()
        humidityAccuracyToken?.invalidate()
        pressureUnitToken?.invalidate()
        pressureAccuracyToken?.invalidate()
    }
}

extension UnitSettingsPresenter: UnitSettingsModuleInput {
    func configure(viewModel: UnitSettingsViewModel, output: UnitSettingsModuleOutput?) {
        self.viewModel = viewModel
        self.output = output
    }

    func dismiss() {
        router.dismiss()
    }
}

extension UnitSettingsPresenter: UnitSettingsViewOutput {
    func viewDidLoad() {
        updateUnits()
        observeUnitChanges()
    }

    func viewDidSelect(row: Int) {
        guard let viewModel else {
            return
        }

        switch viewModel.mode {
        case .measurement:
            let type: UnitSettingsType = row == 0 ? .unit : .accuracy
            openSelection(type: type, measurementType: viewModel.measurementType)
        case .globalUnits:
            guard let measurementType = groupedMeasurementType(at: row) else {
                return
            }
            openSelection(type: .unit, measurementType: measurementType)
        case .resolution:
            guard let measurementType = resolutionMeasurementType(at: row) else {
                return
            }
            guard measurementType != .pressure
                || view.pressureUnit.supportsResolutionSelection else {
                return
            }
            openSelection(type: .accuracy, measurementType: measurementType)
        }
    }
}

extension UnitSettingsPresenter: SelectionModuleOutput {
    // swiftlint:disable:next cyclomatic_complexity
    func selection(module: SelectionModuleInput, didSelectItem item: SelectionItemProtocol, type: UnitSettingsType) {
        switch type {
        case .unit:
            switch item {
            case let temperatureUnit as TemperatureUnit:
                ruuviAppSettingsService.set(temperatureUnit: temperatureUnit)
                view.temperatureUnit = temperatureUnit
            case let humidityUnit as HumidityUnit:
                ruuviAppSettingsService.set(humidityUnit: humidityUnit)
                view.humidityUnit = humidityUnit
            case let pressureUnit as UnitPressure:
                ruuviAppSettingsService.set(pressureUnit: pressureUnit)
                view.pressureUnit = pressureUnit
            default:
                break
            }
        case .accuracy:
            guard let item = item as? MeasurementAccuracyType
            else {
                return
            }

            guard let measurementType = pendingSelectionMeasurementType
                ?? viewModel?.measurementType
            else {
                pendingSelectionMeasurementType = nil
                return
            }
            if measurementType == .pressure,
               !view.pressureUnit.supportsResolutionSelection {
                pendingSelectionMeasurementType = nil
                return
            }
            switch measurementType {
            case .temperature:
                ruuviAppSettingsService.set(temperatureAccuracy: item)
                view.temperatureAccuracy = item
            case .humidity:
                ruuviAppSettingsService.set(humidityAccuracy: item)
                view.humidityAccuracy = item
            case .pressure:
                ruuviAppSettingsService.set(pressureAccuracy: item)
                view.pressureAccuracy = item
            default:
                return
            }
        }
        pendingSelectionMeasurementType = nil
        module.dismiss()
    }
}

extension UnitSettingsPresenter {
    private var groupedMeasurementTypes: [MeasurementType] {
        [.temperature, .humidity, .pressure]
    }

    private var resolutionMeasurementTypes: [MeasurementType] {
        groupedMeasurementTypes
    }

    private func groupedMeasurementType(at row: Int) -> MeasurementType? {
        guard groupedMeasurementTypes.indices.contains(row) else {
            return nil
        }
        return groupedMeasurementTypes[row]
    }

    private func resolutionMeasurementType(at row: Int) -> MeasurementType? {
        guard resolutionMeasurementTypes.indices.contains(row) else {
            return nil
        }
        return resolutionMeasurementTypes[row]
    }

    private func openSelection(
        type: UnitSettingsType,
        measurementType: MeasurementType
    ) {
        let selectionViewModel: SelectionViewModel?
        switch type {
        case .unit:
            selectionViewModel = unitViewModel(for: measurementType)
        case .accuracy:
            selectionViewModel = accuracyViewModel(for: measurementType)
        }

        guard let selectionViewModel else {
            return
        }

        pendingSelectionMeasurementType = measurementType
        router.openSelection(with: selectionViewModel, output: self)
    }

    private func unitViewModel(
        for measurementType: MeasurementType
    ) -> SelectionViewModel? {
        switch measurementType {
        case .temperature:
            return SelectionViewModel(
                title: RuuviLocalization.Settings.Label.TemperatureUnit.text,
                items: unitItems(for: measurementType),
                description: RuuviLocalization.Settings.ChooseTemperatureUnit.text,
                selection: settings.temperatureUnit.title(""),
                measurementType: measurementType,
                unitSettingsType: .unit
            )

        case .humidity:
            return SelectionViewModel(
                title: RuuviLocalization.Settings.Label.HumidityUnit.text,
                items: unitItems(for: measurementType),
                description: RuuviLocalization.Settings.ChooseHumidityUnit.text,
                selection: settings.humidityUnit.title(""),
                measurementType: measurementType,
                unitSettingsType: .unit
            )

        case .pressure:
            return SelectionViewModel(
                title: RuuviLocalization.Settings.Label.PressureUnit.text,
                items: unitItems(for: measurementType),
                description: RuuviLocalization.Settings.ChoosePressureUnit.text,
                selection: settings.pressureUnit.title(""),
                measurementType: measurementType,
                unitSettingsType: .unit
            )

        default:
            return nil
        }
    }

    private func unitItems(
        for measurementType: MeasurementType
    ) -> [SelectionItemProtocol] {
        if viewModel?.mode == .measurement {
            return viewModel?.items ?? []
        }

        switch measurementType {
        case .temperature:
            return [
                TemperatureUnit.celsius,
                TemperatureUnit.fahrenheit,
                TemperatureUnit.kelvin,
            ]
        case .humidity:
            return [
                HumidityUnit.percent,
                HumidityUnit.gm3,
            ]
        case .pressure:
            return [
                UnitPressure.newtonsPerMetersSquared,
                UnitPressure.hectopascals,
                UnitPressure.millimetersOfMercury,
                UnitPressure.inchesOfMercury,
            ]
        default:
            return []
        }
    }

    private func accuracyViewModel(
        for measurementType: MeasurementType
    ) -> SelectionViewModel? {
        var accuracyTitle: String
        var selection: String
        let titleProvider = MeasurementAccuracyTitles()
        switch measurementType {
        case .temperature:
            accuracyTitle = RuuviLocalization.Settings.Temperature.Resolution.title
            selection = titleProvider.formattedTitle(type: settings.temperatureAccuracy, settings: settings)
        case .humidity:
            accuracyTitle = RuuviLocalization.Settings.Humidity.Resolution.title
            selection = titleProvider.formattedTitle(type: settings.humidityAccuracy, settings: settings)
        case .pressure:
            guard view.pressureUnit.supportsResolutionSelection else {
                return nil
            }
            accuracyTitle = RuuviLocalization.Settings.Pressure.Resolution.title
            selection = titleProvider.formattedTitle(type: settings.pressureAccuracy, settings: settings)
        default:
            return nil
        }

        let selectionItems: [MeasurementAccuracyType] = [
            .zero,
            .one,
            .two,
        ]

        return SelectionViewModel(
            title: accuracyTitle,
            items: selectionItems,
            description: RuuviLocalization.Settings.Measurement.Resolution.description,
            selection: selection,
            measurementType: measurementType,
            unitSettingsType: .accuracy
        )
    }

    // swiftlint:disable:next function_body_length
    private func observeUnitChanges() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .TemperatureUnitDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.view.temperatureUnit = sSelf.settings.temperatureUnit
            }
        temperatureAccuracyToken = NotificationCenter
            .default
            .addObserver(
                forName: .TemperatureAccuracyDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.view.temperatureAccuracy = sSelf.settings.temperatureAccuracy
            }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .HumidityUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let sSelf = self else { return }
                    sSelf.view.humidityUnit = sSelf.settings.humidityUnit
                }
            )
        humidityAccuracyToken = NotificationCenter
            .default
            .addObserver(
                forName: .HumidityAccuracyDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let sSelf = self else { return }
                    sSelf.view.humidityAccuracy = sSelf.settings.humidityAccuracy
                }
            )
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .PressureUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let sSelf = self else { return }
                    sSelf.view.pressureUnit = sSelf.settings.pressureUnit
                }
            )
        pressureAccuracyToken = NotificationCenter
            .default
            .addObserver(
                forName: .PressureUnitAccuracyChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let sSelf = self else { return }
                    sSelf.view.pressureAccuracy = sSelf.settings.pressureAccuracy
                }
            )
    }

    private func updateUnits() {
        view.temperatureUnit = settings.temperatureUnit
        view.humidityUnit = settings.humidityUnit
        view.pressureUnit = settings.pressureUnit
        view.temperatureAccuracy = settings.temperatureAccuracy
        view.humidityAccuracy = settings.humidityAccuracy
        view.pressureAccuracy = settings.pressureAccuracy
    }
}
