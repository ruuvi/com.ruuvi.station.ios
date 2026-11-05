// swiftlint:disable file_length
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

    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    private var notificationTokens = [NSObjectProtocol]()
    private var pendingSelectionMeasurementType: MeasurementType?
    private var pendingResolutionTarget: ResolutionSettingsTarget?

    private var viewModel: UnitSettingsViewModel? {
        didSet {
            view.viewModel = viewModel
        }
    }

    var output: UnitSettingsModuleOutput?

    deinit {
        notificationTokens.forEach(notificationCenter.removeObserver)
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
            guard row == 0 || row == 1 else { return }
            let type: UnitSettingsType = row == 0 ? .unit : .accuracy
            openSelection(type: type, measurementType: viewModel.measurementType)
        case .globalUnits:
            guard let measurementType = groupedMeasurementType(at: row) else {
                return
            }
            openSelection(type: .unit, measurementType: measurementType)
        case .resolution:
            guard let target = resolutionTarget(at: row) else {
                return
            }
            guard
                target != .pressure
                    || view.pressureUnit.supportsResolutionSelection
            else {
                return
            }
            openSelection(type: .accuracy, measurementType: target.measurementType, resolutionTarget: target)
        }
    }
}

extension UnitSettingsPresenter: SelectionModuleOutput {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func selection(module: SelectionModuleInput, didSelectItem item: SelectionItemProtocol, type: UnitSettingsType) {
        defer {
            pendingSelectionMeasurementType = nil
            pendingResolutionTarget = nil
            module.dismiss()
        }

        switch type {
        case .unit:
            switch item {
            case let temperatureUnit as TemperatureUnit:
                Task { @MainActor [service = ruuviAppSettingsService!] in
                    _ = try? await service.set(temperatureUnit: temperatureUnit)
                }
                view.temperatureUnit = temperatureUnit
            case let humidityUnit as HumidityUnit:
                Task { @MainActor [service = ruuviAppSettingsService!] in
                    _ = try? await service.set(humidityUnit: humidityUnit)
                }
                view.humidityUnit = humidityUnit
            case let pressureUnit as UnitPressure:
                Task { @MainActor [service = ruuviAppSettingsService!] in
                    _ = try? await service.set(pressureUnit: pressureUnit)
                }
                view.pressureUnit = pressureUnit
            default:
                break
            }
        case .accuracy:
            guard let item = item as? MeasurementAccuracyType
            else {
                return
            }

            if let target = pendingResolutionTarget {
                guard
                    target != .pressure
                        || view.pressureUnit.supportsResolutionSelection
                else {
                    return
                }
                setAccuracy(item, for: target)
            } else if let measurementType = pendingSelectionMeasurementType
                ?? viewModel?.measurementType
            {
                if measurementType == .pressure,
                    !view.pressureUnit.supportsResolutionSelection
                {
                    return
                }
                switch measurementType {
                case .temperature:
                    Task { @MainActor [service = ruuviAppSettingsService!] in
                        _ = try? await service.set(temperatureAccuracy: item)
                    }
                    view.temperatureAccuracy = item
                case .humidity:
                    Task { @MainActor [service = ruuviAppSettingsService!] in
                        _ = try? await service.set(humidityAccuracy: item)
                    }
                    view.humidityAccuracy = item
                case .pressure:
                    Task { @MainActor [service = ruuviAppSettingsService!] in
                        _ = try? await service.set(pressureAccuracy: item)
                    }
                    view.pressureAccuracy = item
                default:
                    return
                }
            } else {
                return
            }
        }
    }
}

extension UnitSettingsPresenter {
    private var groupedMeasurementTypes: [MeasurementType] {
        [.temperature, .humidity, .pressure]
    }

    private var resolutionTargets: [ResolutionSettingsTarget] {
        viewModel?.items.compactMap { $0 as? ResolutionSettingsTarget } ?? []
    }

    private func groupedMeasurementType(at row: Int) -> MeasurementType? {
        guard groupedMeasurementTypes.indices.contains(row) else {
            return nil
        }
        return groupedMeasurementTypes[row]
    }

    private func resolutionTarget(at row: Int) -> ResolutionSettingsTarget? {
        guard resolutionTargets.indices.contains(row) else {
            return nil
        }
        return resolutionTargets[row]
    }

    private func openSelection(
        type: UnitSettingsType,
        measurementType: MeasurementType,
        resolutionTarget: ResolutionSettingsTarget? = nil
    ) {
        let selectionViewModel: SelectionViewModel?
        switch type {
        case .unit:
            selectionViewModel = unitViewModel(for: measurementType)
        case .accuracy:
            selectionViewModel = accuracyViewModel(
                for: measurementType,
                resolutionTarget: resolutionTarget
            )
        }

        guard let selectionViewModel else {
            return
        }

        pendingSelectionMeasurementType = measurementType
        pendingResolutionTarget = resolutionTarget
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
        for measurementType: MeasurementType,
        resolutionTarget: ResolutionSettingsTarget? = nil
    ) -> SelectionViewModel? {
        var accuracyTitle: String
        var selection: String
        let titleProvider = MeasurementAccuracyTitles()
        if let resolutionTarget {
            guard
                resolutionTarget != .pressure
                    || view.pressureUnit.supportsResolutionSelection
            else {
                return nil
            }
            accuracyTitle = resolutionTarget.title("")
            selection = titleProvider.formattedTitle(
                type: accuracy(for: resolutionTarget),
                settings: settings
            )
        } else {
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
        }

        let selectionItems =
            resolutionTarget?.supportedAccuracies ?? [
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
            unitSettingsType: .accuracy,
            resolutionTarget: resolutionTarget
        )
    }

    private func accuracy(for target: ResolutionSettingsTarget) -> MeasurementAccuracyType {
        target.accuracy(
            settings: settings,
            pressureUnit: view.pressureUnit
        )
    }

    private func setAccuracy(
        _ accuracy: MeasurementAccuracyType,
        for target: ResolutionSettingsTarget
    ) {
        switch target {
        case .temperature:
            Task { @MainActor [service = ruuviAppSettingsService!] in
                _ = try? await service.set(temperatureAccuracy: accuracy)
            }
            view.temperatureAccuracy = accuracy
        case .relativeHumidity:
            Task { @MainActor [service = ruuviAppSettingsService!] in
                _ = try? await service.set(relativeHumidityAccuracy: accuracy)
            }
        case .absoluteHumidity:
            Task { @MainActor [service = ruuviAppSettingsService!] in
                _ = try? await service.set(absoluteHumidityAccuracy: accuracy)
            }
        case .dewPoint:
            Task { @MainActor [service = ruuviAppSettingsService!] in
                _ = try? await service.set(dewPointAccuracy: accuracy)
            }
        case .pressure:
            Task { @MainActor [service = ruuviAppSettingsService!] in
                _ = try? await service.set(pressureAccuracy: accuracy)
            }
            view.pressureAccuracy = accuracy
        case .particulateMatter:
            let resolvedAccuracy: MeasurementAccuracyType = accuracy == .two ? .one : accuracy
            Task { @MainActor [service = ruuviAppSettingsService!] in
                _ = try? await service.set(pmAccuracy: resolvedAccuracy)
            }
        case .acceleration:
            Task { @MainActor [service = ruuviAppSettingsService!] in
                _ = try? await service.set(accelerationAccuracy: accuracy)
            }
        case .voltage:
            Task { @MainActor [service = ruuviAppSettingsService!] in
                _ = try? await service.set(voltageAccuracy: accuracy)
            }
        }
        view.reloadSettings()
    }

    private func observeUnitChanges() {
        notificationTokens.forEach(notificationCenter.removeObserver)
        let updates: [(Notification.Name, (UnitSettingsPresenter) -> Void)] = [
            (.TemperatureUnitDidChange, { $0.view.temperatureUnit = $0.settings.temperatureUnit }),
            (.TemperatureAccuracyDidChange, { $0.view.temperatureAccuracy = $0.settings.temperatureAccuracy }),
            (.HumidityUnitDidChange, { $0.view.humidityUnit = $0.settings.humidityUnit }),
            (.HumidityAccuracyDidChange, { $0.view.humidityAccuracy = $0.settings.humidityAccuracy }),
            (.MeasurementAccuracyDidChange, { $0.view.reloadSettings() }),
            (.PressureUnitDidChange, { $0.view.pressureUnit = $0.settings.pressureUnit }),
            (.PressureUnitAccuracyChange, { $0.view.pressureAccuracy = $0.settings.pressureAccuracy }),
        ]
        notificationTokens = updates.map { name, update in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                update(self)
            }
        }
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
