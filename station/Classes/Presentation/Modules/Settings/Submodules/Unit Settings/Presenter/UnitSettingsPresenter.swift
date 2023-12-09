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

    func viewDidSelect(type: UnitSettingsType) {
        switch type {
        case .unit:
            guard let viewModel = unitViewModel()
            else {
                return
            }
            router.openSelection(with: viewModel, output: self)

        case .accuracy:
            guard let viewModel = accuracyViewModel()
            else {
                return
            }
            router.openSelection(with: viewModel, output: self)
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
            guard let viewModel,
                  let item = item as? MeasurementAccuracyType
            else {
                return
            }
            switch viewModel.measurementType {
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
        module.dismiss()
    }
}

extension UnitSettingsPresenter {
    private func unitViewModel() -> SelectionViewModel? {
        guard let viewModel
        else {
            return nil
        }

        switch viewModel.measurementType {
        case .temperature:
            return SelectionViewModel(
                title: RuuviLocalization.Settings.Label.TemperatureUnit.text,
                items: viewModel.items,
                description: RuuviLocalization.Settings.ChooseTemperatureUnit.text,
                selection: settings.temperatureUnit.title(""),
                measurementType: viewModel.measurementType,
                unitSettingsType: .unit
            )

        case .humidity:
            return SelectionViewModel(
                title: RuuviLocalization.Settings.Label.HumidityUnit.text,
                items: viewModel.items,
                description: RuuviLocalization.Settings.ChooseHumidityUnit.text,
                selection: settings.humidityUnit.title(""),
                measurementType: viewModel.measurementType,
                unitSettingsType: .unit
            )

        case .pressure:
            return SelectionViewModel(
                title: RuuviLocalization.Settings.Label.PressureUnit.text,
                items: viewModel.items,
                description: RuuviLocalization.Settings.ChoosePressureUnit.text,
                selection: settings.pressureUnit.title(""),
                measurementType: viewModel.measurementType,
                unitSettingsType: .unit
            )

        default:
            return nil
        }
    }

    private func accuracyViewModel() -> SelectionViewModel? {
        var accuracyTitle: String
        var selection: String
        guard let measurementType = viewModel?.measurementType
        else {
            return nil
        }
        let titleProvider = MeasurementAccuracyTitles()
        switch measurementType {
        case .temperature:
            accuracyTitle = RuuviLocalization.Settings.Temperature.Resolution.title
            selection = titleProvider.formattedTitle(type: settings.temperatureAccuracy, settings: settings)
        case .humidity:
            accuracyTitle = RuuviLocalization.Settings.Humidity.Resolution.title
            selection = titleProvider.formattedTitle(type: settings.humidityAccuracy, settings: settings)
        case .pressure:
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
