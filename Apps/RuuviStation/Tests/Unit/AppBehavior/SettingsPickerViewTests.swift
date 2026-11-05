import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class SettingsPickerViewTests: XCTestCase {
    func testGlobalUnitsAndEveryResolutionRowShowTheConfiguredValue() throws {
        let settings = AppTestSettings()
        settings.temperatureUnit = .fahrenheit
        settings.humidityUnit = .dew
        settings.pressureUnit = .newtonsPerMetersSquared
        for mode in [UnitSettingsMode.globalUnits, .resolution] {
            let controller = try unitController(settings: settings)
            let output = UnitSettingsOutputSpy()
            controller.output = output
            controller.viewModel = .init(
                title: "Settings", items: ResolutionSettingsTarget.allCases, measurementType: .temperature, mode: mode)
            controller.loadViewIfNeeded()
            controller.temperatureUnit = settings.temperatureUnit
            controller.humidityUnit = settings.humidityUnit
            controller.pressureUnit = settings.pressureUnit
            controller.temperatureAccuracy = .one
            controller.humidityAccuracy = .zero
            controller.pressureAccuracy = .two
            let expected =
                mode == .globalUnits
                ? [
                    TemperatureUnit.fahrenheit.title(""), HumidityUnit.dew.title(TemperatureUnit.fahrenheit.symbol),
                    UnitPressure.newtonsPerMetersSquared.title(""),
                ]
                : ResolutionSettingsTarget.allCases.map { target in
                    MeasurementAccuracyTitles().formattedTitle(
                        type: target.accuracy(settings: settings, pressureUnit: controller.pressureUnit),
                        settings: settings) + " "
                        + target.unitSymbol(
                            temperatureUnit: controller.temperatureUnit, pressureUnit: controller.pressureUnit)
                }
            XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 0), expected.count)
            for (row, value) in expected.enumerated() {
                let index = IndexPath(row: row, section: 0)
                let cell = try XCTUnwrap(cell(controller, at: index) as? UnitSettingsTableViewCell)
                XCTAssertEqual(cell.valueLbl.text, value)
                XCTAssertFalse(try XCTUnwrap(cell.titleLbl.text).isEmpty)
                let enabled = mode != .resolution || ResolutionSettingsTarget.allCases[row] != .pressure
                XCTAssertEqual(cell.isUserInteractionEnabled, enabled)
                XCTAssertEqual(
                    controller.tableView(controller.tableView, willSelectRowAt: index), enabled ? index : nil)
                controller.tableView(controller.tableView, didSelectRowAt: index)
                XCTAssertEqual(output.rows.contains(row), enabled)
            }
            for width in [CGFloat(320), CGFloat(852)] {
                controller.view.frame = .init(x: 0, y: 0, width: width, height: 700)
                controller.viewDidLayoutSubviews()
                let header = try XCTUnwrap(controller.tableView.tableHeaderView)
                XCTAssertGreaterThan(header.frame.height, 32)
                XCTAssertEqual(header.frame.width, width)
                XCTAssertTrue(header.subviews.contains { ($0 as? UILabel)?.text?.isEmpty == false })
            }
            controller.localize()
            controller.reloadSettings()
            XCTAssertEqual(controller.title, "Settings")
            XCTAssertEqual(output.loads, 1)
        }
    }

    func testMeasurementRowsUseTheRightSymbolsIncludingDewPointAndPressureRestrictions() throws {
        let controller = try unitController(settings: AppTestSettings())
        let output = UnitSettingsOutputSpy()
        controller.output = output
        controller.loadViewIfNeeded()
        for type in [MeasurementType.temperature, .humidity, .pressure, .co2] {
            for dew in [false, true] {
                controller.temperatureUnit = .fahrenheit
                controller.humidityUnit = dew ? .dew : .percent
                controller.pressureUnit = .hectopascals
                controller.viewModel = .init(title: "Measurement", items: [], measurementType: type)
                XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 0), 2)
                for row in 0..<2 {
                    let cell = try XCTUnwrap(
                        cell(controller, at: .init(row: row, section: 0)) as? UnitSettingsTableViewCell)
                    let symbol: String
                    switch type {
                    case .temperature: symbol = TemperatureUnit.fahrenheit.symbol
                    case .humidity: symbol = dew ? TemperatureUnit.fahrenheit.symbol : HumidityUnit.percent.symbol
                    case .pressure: symbol = UnitPressure.hectopascals.ruuviSymbol
                    default: symbol = RuuviLocalization.na
                    }
                    if row == 0 {
                        let title =
                            type == .temperature
                            ? TemperatureUnit.fahrenheit.title("")
                            : type == .humidity
                                ? controller.humidityUnit.title(dew ? TemperatureUnit.fahrenheit.symbol : "")
                                : type == .pressure ? UnitPressure.hectopascals.title("") : RuuviLocalization.na
                        XCTAssertEqual(cell.valueLbl.text, title)
                    } else {
                        XCTAssertTrue(try XCTUnwrap(cell.valueLbl.text).hasSuffix(symbol))
                    }
                }
                XCTAssertTrue(controller.tableView.tableHeaderView?.subviews.isEmpty == true)
            }
        }
        controller.viewModel = .init(title: "Pressure", items: [], measurementType: .pressure)
        controller.pressureUnit = .newtonsPerMetersSquared
        XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 0), 1)
        controller.tableView(controller.tableView, didSelectRowAt: .init(row: 1, section: 0))
        XCTAssertTrue(output.rows.isEmpty)
        controller.tableView(controller.tableView, didSelectRowAt: .init(row: 0, section: 0))
        XCTAssertEqual(output.rows, [0])
        controller.viewModel = .init(title: "Resolution", items: [], measurementType: .temperature, mode: .resolution)
        XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(
            controller.tableView.tableHeaderView?.subviews.compactMap { ($0 as? UILabel)?.text }.first,
            RuuviLocalization.Settings.Measurement.Resolution.empty)
    }

    func testUnitPickerMarksOnlyTheSelectedItemAndUpdatesAfterReconfiguration() throws {
        let controller = try selectionController()
        let output = SelectionOutputSpy()
        controller.output = output
        let settings = AppTestSettings()
        settings.temperatureUnit = .fahrenheit
        controller.settings = settings
        controller.viewModel = .init(
            title: "Humidity", items: [HumidityUnit.percent, HumidityUnit.gm3, HumidityUnit.dew],
            description: "Choose a humidity unit", selection: HumidityUnit.dew.title(""),
            measurementType: .humidity, unitSettingsType: .unit)
        controller.loadViewIfNeeded()
        XCTAssertEqual(controller.descriptionTextView.text, "Choose a humidity unit")
        XCTAssertEqual(controller.title, "Humidity")
        for (row, unit) in [HumidityUnit.percent, .gm3, .dew].enumerated() {
            let index = IndexPath(row: row, section: 0)
            let cell = try XCTUnwrap(
                cell(controller, at: index)
                    as? SelectionTableViewCell)
            XCTAssertEqual(cell.nameLabel.text, unit.title(unit == .dew ? TemperatureUnit.fahrenheit.symbol : ""))
            XCTAssertEqual(cell.accessoryType, unit == .dew ? .checkmark : .none)
            controller.tableView(controller.tableView, didSelectRowAt: index)
        }
        XCTAssertEqual(output.rows, [0, 1, 2])
        XCTAssertEqual(output.loads, 1)
        controller.viewModel = .init(
            title: "Empty", items: [], description: "No choices", selection: "",
            measurementType: .temperature, unitSettingsType: .unit)
        XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(controller.descriptionTextView.text, "No choices")
    }

    func testResolutionPickerUsesEachTargetsUnitAndLocaleFormatting() throws {
        let controller = try selectionController()
        let output = SelectionOutputSpy()
        controller.output = output
        let settings = AppTestSettings()
        controller.settings = settings
        controller.loadViewIfNeeded()
        controller.temperatureUnit = .kelvin
        controller.humidityUnit = .dew
        controller.pressureUnit = .inchesOfMercury
        for target in ResolutionSettingsTarget.allCases {
            let selection = MeasurementAccuracyTitles().formattedTitle(type: .one, settings: settings)
            controller.viewModel = .init(
                title: target.title(""), items: target.supportedAccuracies,
                description: "Precision", selection: selection, measurementType: target.measurementType,
                unitSettingsType: .accuracy, resolutionTarget: target)
            for (row, accuracy) in target.supportedAccuracies.enumerated() {
                let cell = try XCTUnwrap(cell(controller, at: .init(row: row, section: 0)) as? SelectionTableViewCell)
                let value = MeasurementAccuracyTitles().formattedTitle(type: accuracy, settings: settings)
                XCTAssertEqual(
                    cell.nameLabel.text,
                    value + " "
                        + target.unitSymbol(
                            temperatureUnit: .kelvin, pressureUnit: .inchesOfMercury))
                XCTAssertEqual(cell.accessoryType, accuracy == .one ? .checkmark : .none)
            }
        }
        for type in [MeasurementType.temperature, .humidity, .pressure, .co2] {
            for humidity in [HumidityUnit.dew, .percent] {
                controller.humidityUnit = humidity
                controller.viewModel = .init(
                    title: "Precision", items: [MeasurementAccuracyType.one],
                    description: "", selection: "", measurementType: type, unitSettingsType: .accuracy)
                let cell = try XCTUnwrap(cell(controller, at: .init(row: 0, section: 0)) as? SelectionTableViewCell)
                let symbol =
                    type == .temperature
                    ? TemperatureUnit.kelvin.symbol
                    : type == .humidity
                        ? (humidity == .dew ? TemperatureUnit.kelvin.symbol : humidity.symbol)
                        : type == .pressure ? UnitPressure.inchesOfMercury.ruuviSymbol : RuuviLocalization.na
                XCTAssertTrue(try XCTUnwrap(cell.nameLabel.text).hasSuffix(symbol))
            }
        }
        for width in [CGFloat(320), CGFloat(852)] {
            controller.view.frame = .init(x: 0, y: 0, width: width, height: 700)
            controller.viewDidLayoutSubviews()
            XCTAssertEqual(controller.tableView.tableFooterView?.frame.width, width)
        }
    }

    private func cell(_ controller: UITableViewController, at index: IndexPath) -> UITableViewCell? {
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 1000)
        controller.tableView.reloadData()
        controller.tableView.layoutIfNeeded()
        return controller.tableView.cellForRow(at: index)
    }

    private func unitController(settings: AppTestSettings) throws -> UnitSettingsTableViewController {
        let controller = try XCTUnwrap(
            UIStoryboard(name: "UnitSettings", bundle: .main)
                .instantiateInitialViewController() as? UnitSettingsTableViewController)
        controller.settings = settings
        return controller
    }

    private func selectionController() throws -> SelectionTableViewController {
        try XCTUnwrap(
            UIStoryboard(name: "Selection", bundle: .main)
                .instantiateInitialViewController() as? SelectionTableViewController)
    }
}

final class UnitSettingsOutputSpy: UnitSettingsViewOutput {
    var loads = 0
    var rows = [Int]()
    func viewDidLoad() { loads += 1 }
    func viewDidSelect(row: Int) { rows.append(row) }
}

final class SelectionOutputSpy: SelectionViewOutput {
    var loads = 0
    var rows = [Int]()
    func viewDidLoad() { loads += 1 }
    func viewDidSelect(itemAtIndex index: Int) { rows.append(index) }
}
