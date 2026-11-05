import Foundation
import RuuviLocal
import RuuviOntology
import XCTest
@testable import station

@MainActor final class OffsetCorrectionPresenterTests: XCTestCase {
    func testTemperatureCalibrationConvertsEveryDisplayedUnitBackToCelsiusExactlyOnce() async throws {
        for (unit, correct) in [(TemperatureUnit.celsius, 25.0), (.fahrenheit, 77), (.kelvin, 298.15)] {
            let fixture = OffsetCorrectionFixture()
            fixture.measurements.settings.temperatureUnit = unit
            fixture.configure(.temperature, offsets: fixture.offsets())
            await waitForAppState("stored temperature") { fixture.view.viewModel.originalValue.value != nil }
            XCTAssertEqual(fixture.view.viewModel.originalValue.value, 20)
            XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 22)
            XCTAssertEqual(fixture.view.viewModel.temperatureUnit.value, unit)
            fixture.presenter?.viewDidSetCorrectValue(correctValue: correct)
            await waitForAppState("calibration saved") {
                !fixture.service.calls.isEmpty && abs((fixture.view.viewModel.correctedValue.value ?? 0) - 25) < 0.00001
            }
            let call = try XCTUnwrap(fixture.service.calls.last)
            XCTAssertEqual(try XCTUnwrap(call.offset), 5, accuracy: 0.00001)
            XCTAssertEqual(call.type, .temperature)
            XCTAssertEqual(call.sensor.id, fixture.measurements.sensor.id)
            XCTAssertEqual(call.record?.temperature?.value, 20)
            XCTAssertEqual(try XCTUnwrap(fixture.view.viewModel.correctedValue.value), 25, accuracy: 0.00001)
        }
    }

    func testPressureCalibrationConvertsEverySupportedUnitBackToHectopascals() async throws {
        for unit in [UnitPressure.hectopascals, .newtonsPerMetersSquared, .inchesOfMercury, .millimetersOfMercury] {
            let fixture = OffsetCorrectionFixture()
            fixture.measurements.settings.pressureUnit = unit
            fixture.configure(.pressure, offsets: fixture.offsets())
            await waitForAppState("stored pressure") { fixture.view.viewModel.originalValue.value != nil }
            XCTAssertEqual(fixture.view.viewModel.originalValue.value, 1000)
            XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 1010)
            fixture.presenter?.viewDidSetCorrectValue(
                correctValue: Pressure(value: 1020, unit: .hectopascals)
                    .converted(to: unit).value)
            await waitForAppState("pressure saved") {
                !fixture.service.calls.isEmpty && abs((fixture.view.viewModel.correctedValue.value ?? 0) - 1020) < 0.001
            }
            XCTAssertEqual(try XCTUnwrap(fixture.service.calls.last?.offset), 20, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(fixture.view.viewModel.correctedValue.value), 1020, accuracy: 0.001)
        }
    }

    func testHumidityCalibrationUsesAFractionAndClearingEveryMetricRestoresOriginalValues() async throws {
        for type in [OffsetCorrectionType.temperature, .humidity, .pressure] {
            let fixture = OffsetCorrectionFixture()
            fixture.configure(type, offsets: fixture.offsets())
            await waitForAppState("stored original reading") { fixture.view.viewModel.originalValue.value != nil }
            XCTAssertEqual(fixture.view.viewModel.hasOffsetValue.value, true)
            if type == .humidity {
                fixture.presenter?.viewDidSetCorrectValue(correctValue: 65)
                await waitForAppState("humidity saved") {
                    !fixture.service.calls.isEmpty
                        && abs((fixture.view.viewModel.correctedValue.value ?? 0) - 0.65) < 0.00001
                }
                XCTAssertEqual(try XCTUnwrap(fixture.service.calls.last?.offset), 0.15, accuracy: 0.00001)
                XCTAssertEqual(try XCTUnwrap(fixture.view.viewModel.correctedValue.value), 0.65, accuracy: 0.00001)
            }
            let count = fixture.service.calls.count
            fixture.presenter?.viewDidClearOffsetValue()
            await waitForAppState("calibration cleared") {
                fixture.service.calls.count == count + 1 && fixture.view.viewModel.hasOffsetValue.value == false
            }
            XCTAssertNil(fixture.service.calls.last?.offset)
            XCTAssertEqual(fixture.view.viewModel.hasOffsetValue.value, false)
            XCTAssertEqual(fixture.view.viewModel.correctedValue.value, fixture.view.viewModel.originalValue.value)
            fixture.presenter?.viewDidOpenCalibrateDialog()
            fixture.presenter?.viewDidOpenClearDialog()
            XCTAssertEqual(fixture.view.calibrationDialogs, 1)
            XCTAssertEqual(fixture.view.clearDialogs, 1)
        }
    }

    func testFailedSaveAndClearPreserveCalibrationAndPresentTheError() async {
        let fixture = OffsetCorrectionFixture()
        fixture.configure(.temperature, offsets: fixture.offsets())
        await waitForAppState("stored reading") { fixture.view.viewModel.originalValue.value != nil }
        fixture.service.failure = .failedToParseNetworkResponse
        fixture.presenter?.viewDidSetCorrectValue(correctValue: 30)
        await waitForAppState("save error shown") { fixture.errors.errors.count == 1 }
        XCTAssertEqual(fixture.view.viewModel.offsetCorrectionValue.value, 2)
        XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 22)
        fixture.presenter?.viewDidClearOffsetValue()
        await waitForAppState("clear error shown") { fixture.errors.errors.count == 2 }
        XCTAssertEqual(fixture.view.viewModel.offsetCorrectionValue.value, 2)
    }

    func testInitialLiveReadingsAndSettingsChangesRefreshWithoutApplyingOffsetsTwice() async {
        let fixture = OffsetCorrectionFixture()
        fixture.measurements.storage.latestOverride = nil
        fixture.configure(.temperature)
        fixture.presenter?.viewDidLoad()
        fixture.presenter?.viewDidLoad()
        XCTAssertEqual(fixture.reactor.latest.count, 1)
        XCTAssertEqual(fixture.reactor.settings.count, 1)
        fixture.reactor.sendLatest(fixture.measurements.sensor, .initial([fixture.measurements.record().any]))
        XCTAssertEqual(fixture.view.viewModel.originalValue.value, 20)
        fixture.reactor.sendSettings(fixture.measurements.sensor, .initial([fixture.offsets()]))
        XCTAssertEqual(fixture.view.viewModel.originalValue.value, 20)
        XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 22)
        fixture.reactor.sendSettings(fixture.measurements.sensor, .update(fixture.offsets(5)))
        XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 25)
        let newer = fixture.measurements.record(date: Date().addingTimeInterval(10), temperature: 23)
        fixture.reactor.sendLatest(fixture.measurements.sensor, .update(newer.any))
        XCTAssertEqual(fixture.view.viewModel.originalValue.value, 23)
        XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 28)
        fixture.reactor.sendSettings(fixture.measurements.sensor, .delete(fixture.offsets(5)))
        XCTAssertEqual(fixture.view.viewModel.hasOffsetValue.value, false)
        XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 23)
    }

    func testInvalidInputsAndMissingOriginalReadingsCannotCreateACalibration() async {
        let fixture = OffsetCorrectionFixture()
        fixture.measurements.storage.latestOverride = nil
        fixture.configure(.temperature)
        fixture.presenter?.viewDidSetCorrectValue(correctValue: 30)
        await Task.yield()
        XCTAssertTrue(fixture.service.calls.isEmpty)
        fixture.view.viewModel.originalValue.value = 20
        for value in [Double.nan, .infinity, -.infinity] {
            fixture.presenter?.viewDidSetCorrectValue(correctValue: value)
        }
        await Task.yield()
        XCTAssertTrue(fixture.service.calls.isEmpty)
    }
}
