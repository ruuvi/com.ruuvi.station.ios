import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class SelectionPresenterTests: XCTestCase {
    func testSelectionForwardsTheExactItemAndTypeAndAllowsTheParentToDismiss() {
        let presenter = SelectionPresenter()
        let view = SelectionViewSpy()
        let router = SelectionRouterSpy()
        let output = SelectionParentSpy()
        defer { output.module = nil }
        presenter.view = view
        presenter.router = router
        presenter.settings = AppTestSettings()
        presenter.settings.temperatureUnit = .kelvin
        presenter.settings.humidityUnit = .dew
        presenter.settings.pressureUnit = .millimetersOfMercury
        presenter.viewDidLoad()
        XCTAssertEqual(view.temperatureUnit, .kelvin)
        XCTAssertEqual(view.humidityUnit, .dew)
        XCTAssertEqual(view.pressureUnit, .millimetersOfMercury)
        for type in [UnitSettingsType.unit, .accuracy] {
            let choices: [SelectionItemProtocol] =
                type == .unit
                ? [TemperatureUnit.celsius, TemperatureUnit.fahrenheit]
                : [MeasurementAccuracyType.zero, MeasurementAccuracyType.two]
            presenter.configure(
                viewModel: .init(
                    title: "Choices", items: choices, description: "Description", selection: "",
                    measurementType: .temperature, unitSettingsType: type), output: output)
            XCTAssertEqual(view.viewModel?.title, "Choices")
            for index in choices.indices {
                presenter.viewDidSelect(itemAtIndex: index)
                XCTAssertTrue(output.module === presenter)
                XCTAssertEqual(output.item?.title(""), choices[index].title(""))
                XCTAssertEqual(output.type, type)
            }
        }
        XCTAssertEqual(output.calls, 4)
        XCTAssertEqual(router.dismissals, 0)
        output.module?.dismiss()
        XCTAssertEqual(router.dismissals, 1)
    }

    func testMissingEmptyAndStaleSelectionsDismissWithoutForwardingAnInvalidItem() {
        let presenter = SelectionPresenter()
        let view = SelectionViewSpy()
        let router = SelectionRouterSpy()
        let output = SelectionParentSpy()
        presenter.view = view
        presenter.router = router
        presenter.viewDidSelect(itemAtIndex: 0)
        XCTAssertEqual(router.dismissals, 1)
        for items: [SelectionItemProtocol] in [[], [TemperatureUnit.celsius]] {
            presenter.configure(
                viewModel: .init(
                    title: "", items: items, description: "", selection: "",
                    measurementType: .temperature, unitSettingsType: .unit), output: output)
            for index in [-1, items.count, Int.max] {
                presenter.viewDidSelect(itemAtIndex: index)
            }
        }
        XCTAssertEqual(router.dismissals, 7)
        XCTAssertEqual(output.calls, 0)
    }
}

private final class SelectionViewSpy: SelectionViewInput {
    var viewModel: SelectionViewModel?
    var temperatureUnit: TemperatureUnit = .celsius
    var humidityUnit: HumidityUnit = .percent
    var pressureUnit: UnitPressure = .hectopascals
}

private final class SelectionRouterSpy: SelectionRouterInput {
    var dismissals = 0
    func dismiss() { dismissals += 1 }
}

private final class SelectionParentSpy: SelectionModuleOutput {
    var calls = 0
    var module: SelectionModuleInput?
    var item: SelectionItemProtocol?
    var type: UnitSettingsType?
    func selection(module: SelectionModuleInput, didSelectItem item: SelectionItemProtocol, type: UnitSettingsType) {
        calls += 1
        self.module = module
        self.item = item
        self.type = type
    }
}
