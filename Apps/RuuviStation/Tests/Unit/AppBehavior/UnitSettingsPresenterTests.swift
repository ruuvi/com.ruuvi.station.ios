import Foundation
import RuuviLocal
import RuuviOntology
import XCTest
@testable import station

@MainActor final class UnitSettingsPresenterTests: XCTestCase {
    func testGlobalUnitRowsPresentTheSupportedUnitsAndPreserveCurrentSelections() throws {
        let fixture = UnitSettingsFixture()
        fixture.presenter.viewDidSelect(row: -1)
        fixture.presenter.viewDidSelect(row: 3)
        XCTAssertTrue(fixture.router.selections.isEmpty)
        for (row, type) in [MeasurementType.temperature, .humidity, .pressure].enumerated() {
            fixture.presenter.viewDidSelect(row: row)
            let model = try XCTUnwrap(fixture.router.selections.last)
            XCTAssertEqual(model.measurementType, type)
            XCTAssertEqual(model.unitSettingsType, .unit)
            XCTAssertEqual(model.items.count, [3, 2, 4][row])
            XCTAssertFalse(model.title.isEmpty)
            XCTAssertFalse(model.description.isEmpty)
            XCTAssertTrue(model.items.map { $0.title("") }.contains(model.selection))
        }
        fixture.presenter.dismiss()
        XCTAssertEqual(fixture.router.dismissals, 1)
    }

    func testEveryUnitSelectionPersistsThroughTheServiceAndDismissesThePicker() async {
        let fixture = UnitSettingsFixture()
        let units: [SelectionItemProtocol] = [
            TemperatureUnit.celsius, TemperatureUnit.fahrenheit, TemperatureUnit.kelvin,
            HumidityUnit.percent, HumidityUnit.gm3, HumidityUnit.dew,
            UnitPressure.newtonsPerMetersSquared, UnitPressure.hectopascals,
            UnitPressure.millimetersOfMercury, UnitPressure.inchesOfMercury,
        ]
        for (index, unit) in units.enumerated() {
            fixture.presenter.selection(module: fixture.selection, didSelectItem: unit, type: .unit)
            await waitForAppState("unit save") { fixture.service.calls.count == index + 1 }
            if let value = unit as? TemperatureUnit {
                XCTAssertEqual(fixture.settings.temperatureUnit, value)
                XCTAssertEqual(fixture.view.temperatureUnit, value)
            } else if let value = unit as? HumidityUnit {
                XCTAssertEqual(fixture.settings.humidityUnit, value)
                XCTAssertEqual(fixture.view.humidityUnit, value)
            } else if let value = unit as? UnitPressure {
                XCTAssertEqual(fixture.settings.pressureUnit, value)
                XCTAssertEqual(fixture.view.pressureUnit, value)
            }
            XCTAssertEqual(fixture.selection.dismissals, index + 1)
        }
        fixture.presenter.selection(module: fixture.selection, didSelectItem: UnsupportedUnitChoice(), type: .unit)
        fixture.presenter.selection(module: fixture.selection, didSelectItem: UnsupportedUnitChoice(), type: .accuracy)
        XCTAssertEqual(fixture.service.calls.count, units.count)
        XCTAssertEqual(fixture.selection.dismissals, units.count + 2)
    }

    func testMeasurementModeUsesItsProvidedUnitsAndDoesNotOpenInvalidRows() async throws {
        for type in [MeasurementType.temperature, .humidity, .pressure, .co2] {
            let fixture = UnitSettingsFixture(mode: .measurement, type: type, items: [TemperatureUnit.kelvin])
            fixture.presenter.viewDidSelect(row: -1)
            fixture.presenter.viewDidSelect(row: 2)
            XCTAssertTrue(fixture.router.selections.isEmpty)
            fixture.presenter.viewDidSelect(row: 0)
            fixture.presenter.viewDidSelect(row: 1)
            if type == .co2 {
                XCTAssertTrue(fixture.router.selections.isEmpty)
                fixture.presenter.selection(
                    module: fixture.selection, didSelectItem: MeasurementAccuracyType.one,
                    type: .accuracy)
                XCTAssertTrue(fixture.service.calls.isEmpty)
            } else {
                XCTAssertEqual(fixture.router.selections.count, 2)
                XCTAssertEqual(fixture.router.selections[0].items.count, 1)
                XCTAssertEqual(fixture.router.selections[0].items[0].title(""), TemperatureUnit.kelvin.title(""))
                XCTAssertEqual(fixture.router.selections[1].items.count, 3)
                fixture.presenter.selection(
                    module: fixture.selection, didSelectItem: MeasurementAccuracyType.one,
                    type: .accuracy)
                await waitForAppState("accuracy save") { fixture.service.calls.count == 1 }
                XCTAssertEqual(fixture.selection.dismissals, 1)
            }
        }
    }

    func testEachResolutionRowWritesItsOwnAccuracyAndPMClampsUnsupportedDecimals() async throws {
        let targets = ResolutionSettingsTarget.allCases
        let fixture = UnitSettingsFixture(mode: .resolution, items: targets)
        let keys = [
            "temperatureAccuracy", "relativeHumidityAccuracy", "absoluteHumidityAccuracy", "dewPointAccuracy",
            "pressureAccuracy", "pmAccuracy", "accelerationAccuracy", "voltageAccuracy",
        ]
        fixture.presenter.viewDidSelect(row: -1)
        fixture.presenter.viewDidSelect(row: targets.count)
        XCTAssertTrue(fixture.router.selections.isEmpty)
        for (index, target) in targets.enumerated() {
            fixture.presenter.viewDidSelect(row: index)
            let picker = try XCTUnwrap(fixture.router.selections.last)
            XCTAssertEqual(picker.resolutionTarget, target)
            XCTAssertEqual(picker.unitSettingsType, .accuracy)
            XCTAssertEqual(picker.items.count, target == .particulateMatter ? 2 : 3)
            fixture.presenter.selection(
                module: fixture.selection, didSelectItem: MeasurementAccuracyType.two,
                type: .accuracy)
            await waitForAppState("resolution save") { fixture.service.calls.count == index + 1 }
            XCTAssertEqual(fixture.service.calls.last, keys[index])
            XCTAssertEqual(
                target.accuracy(settings: fixture.settings, pressureUnit: fixture.view.pressureUnit),
                target == .particulateMatter ? .one : .two)
        }
        XCTAssertEqual(fixture.view.reloads, targets.count)
    }

    func testPressureInPascalsCannotSelectFractionalResolutionEvenIfTheUnitChangesWhileAPickerIsOpen() {
        for mode in [UnitSettingsMode.measurement, .resolution] {
            let fixture = UnitSettingsFixture(mode: mode, type: .pressure, items: [ResolutionSettingsTarget.pressure])
            let row = mode == .measurement ? 1 : 0
            fixture.view.pressureUnit = .newtonsPerMetersSquared
            fixture.presenter.viewDidSelect(row: row)
            XCTAssertTrue(fixture.router.selections.isEmpty)
            fixture.view.pressureUnit = .hectopascals
            fixture.presenter.viewDidSelect(row: row)
            XCTAssertEqual(fixture.router.selections.count, 1)
            fixture.view.pressureUnit = .newtonsPerMetersSquared
            fixture.presenter.selection(
                module: fixture.selection, didSelectItem: MeasurementAccuracyType.two,
                type: .accuracy)
            XCTAssertTrue(fixture.service.calls.isEmpty)
            XCTAssertEqual(fixture.selection.dismissals, 1)
        }
    }

    func testNotificationsRefreshEachUnitAndRepeatedViewLoadingDoesNotDuplicateObservers() {
        let fixture = UnitSettingsFixture()
        fixture.presenter.viewDidLoad()
        fixture.settings.temperatureUnit = .kelvin
        fixture.settings.humidityUnit = .gm3
        fixture.settings.pressureUnit = .millimetersOfMercury
        fixture.settings.temperatureAccuracy = .zero
        fixture.settings.humidityAccuracy = .one
        fixture.settings.pressureAccuracy = .zero
        for name in [
            Notification.Name.TemperatureUnitDidChange, .HumidityUnitDidChange, .PressureUnitDidChange,
            .TemperatureAccuracyDidChange, .HumidityAccuracyDidChange, .PressureUnitAccuracyChange,
            .MeasurementAccuracyDidChange,
        ] {
            fixture.notifications.post(name: name, object: nil)
        }
        XCTAssertEqual(fixture.view.temperatureUnit, .kelvin)
        XCTAssertEqual(fixture.view.humidityUnit, .gm3)
        XCTAssertEqual(fixture.view.pressureUnit, .millimetersOfMercury)
        XCTAssertEqual(fixture.view.temperatureAccuracy, .zero)
        XCTAssertEqual(fixture.view.humidityAccuracy, .one)
        XCTAssertEqual(fixture.view.pressureAccuracy, .zero)
        XCTAssertEqual(fixture.view.reloads, 1)
    }

    func testPendingPreferenceSaveDoesNotRetainADismissedPresenter() async {
        var fixture: UnitSettingsFixture? = UnitSettingsFixture()
        weak var presenter = fixture?.presenter
        let service = fixture!.service
        var suspended: CheckedContinuation<Void, Never>?
        service.beforeSave = { await withCheckedContinuation { suspended = $0 } }
        fixture?.presenter.selection(module: fixture!.selection, didSelectItem: TemperatureUnit.kelvin, type: .unit)
        await waitForAppState("suspended preference save") { suspended != nil }
        fixture = nil
        XCTAssertNil(presenter)
        suspended?.resume()
        await Task.yield()
        XCTAssertEqual(service.settings.temperatureUnit, .kelvin)
    }
}
