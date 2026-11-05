import Foundation
import RuuviOntology
@testable import station

@MainActor final class UnitSettingsFixture {
    let settings = AppTestSettings()
    let view = UnitSettingsViewSpy()
    let router = UnitSettingsRouterSpy()
    let selection = UnitSelectionSpy()
    let notifications = NotificationCenter()
    let service: AppSettingsServiceSpy
    let presenter: UnitSettingsPresenter

    init(
        mode: UnitSettingsMode = .globalUnits, type: MeasurementType = .temperature,
        items: [SelectionItemProtocol] = []
    ) {
        service = AppSettingsServiceSpy(settings: settings)
        presenter = UnitSettingsPresenter(notificationCenter: notifications)
        presenter.view = view
        presenter.router = router
        presenter.settings = settings
        presenter.ruuviAppSettingsService = service
        presenter.configure(
            viewModel: .init(title: "Units", items: items, measurementType: type, mode: mode), output: nil)
        presenter.viewDidLoad()
    }
}

final class UnitSettingsViewSpy: UnitSettingsViewInput {
    var viewModel: UnitSettingsViewModel?
    var temperatureUnit: TemperatureUnit = .celsius
    var temperatureAccuracy: MeasurementAccuracyType = .two
    var humidityUnit: HumidityUnit = .percent
    var humidityAccuracy: MeasurementAccuracyType = .two
    var pressureUnit: UnitPressure = .hectopascals
    var pressureAccuracy: MeasurementAccuracyType = .two
    var reloads = 0
    func reloadSettings() { reloads += 1 }
}

final class UnitSettingsRouterSpy: UnitSettingsRouterInput {
    var dismissals = 0
    var selections = [SelectionViewModel]()
    func dismiss() { dismissals += 1 }
    func openSelection(with viewModel: SelectionViewModel, output: SelectionModuleOutput?) {
        selections.append(viewModel)
    }
}

final class UnitSelectionSpy: SelectionModuleInput {
    var dismissals = 0
    func configure(viewModel: SelectionViewModel, output: SelectionModuleOutput?) {}
    func dismiss() { dismissals += 1 }
}

struct UnsupportedUnitChoice: SelectionItemProtocol {
    var title: (String) -> String { { _ in "Unsupported" } }
}
