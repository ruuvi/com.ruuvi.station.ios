import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class OffsetCorrectionViewTests: XCTestCase {
    func testEveryCalibrationScreenRendersOriginalCorrectedAndClearedReadings() async throws {
        for type in [OffsetCorrectionType.temperature, .humidity, .pressure] {
            let fixture = OffsetCorrectionFixture()
            let controller = try makeController(fixture)
            let output = OffsetCorrectionOutputSpy()
            controller.output = output
            let settings = fixture.offsets()
            let model = OffsetCorrectionViewModel(type: type, sensorSettings: settings)
            model.temperatureUnit.value = .celsius
            model.humidityUnit.value = .percent
            model.pressureUnit.value = .hectopascals
            controller.viewModel = model
            controller.loadViewIfNeeded()
            let record = fixture.measurements.record()
            model.update(ruuviTagRecord: record.with(sensorSettings: settings))
            await flushAppBindings()
            controller.view.layoutIfNeeded()
            XCTAssertEqual(controller.title, model.title)
            XCTAssertEqual(controller.correctedValueTitle.text, RuuviLocalization.OffsetCorrection.CorrectedValue.title)
            XCTAssertEqual(controller.originalValueTitle.text, RuuviLocalization.OffsetCorrection.OriginalValue.title)
            XCTAssertEqual(
                controller.descriptionTextView.text, RuuviLocalization.OffsetCorrection.CalibrationDescription.text)
            let original: String?
            let corrected: String?
            switch type {
            case .temperature:
                original = fixture.measurements.measurement.string(
                    for: Temperature(value: 20, unit: .celsius), allowSettings: false)
                corrected = fixture.measurements.measurement.string(
                    for: Temperature(value: 22, unit: .celsius), allowSettings: false)
            case .humidity:
                original = "50.0%"
                corrected = "60.0%"
            case .pressure:
                original = fixture.measurements.measurement.string(
                    for: Pressure(value: 1000, unit: .hectopascals), allowSettings: false)
                corrected = fixture.measurements.measurement.string(
                    for: Pressure(value: 1010, unit: .hectopascals), allowSettings: false)
            }
            XCTAssertEqual(controller.originalValueLabel.text, original)
            XCTAssertEqual(controller.correctedValueLabel.text, corrected)
            XCTAssertFalse(controller.offsetValueLabel.text?.isEmpty ?? true)
            XCTAssertTrue(controller.originalValueUpdateTimeLabel.text?.hasPrefix("(") == true)
            XCTAssertFalse(controller.correctedValueView.isHidden)
            XCTAssertTrue(controller.clearButton.isEnabled)
            controller.calibrateButton.sendActions(for: .touchUpInside)
            controller.clearButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(output.calibrateDialogs, 1)
            XCTAssertEqual(output.clearDialogs, 1)
            XCTAssertEqual(output.loads, 1)
            model.update(sensorSettings: fixture.offsets(nil, nil, nil))
            model.update(ruuviTagRecord: record)
            await flushAppBindings()
            XCTAssertTrue(controller.correctedValueView.isHidden)
            XCTAssertFalse(controller.clearButton.isEnabled)
            XCTAssertEqual(controller.clearButton.alpha, 0.3, accuracy: 0.001)
            XCTAssertEqual(controller.correctedValueLabel.text, original)
            controller.viewModel = OffsetCorrectionViewModel(type: type, sensorSettings: settings)
            XCTAssertFalse(controller.correctedValueView.isHidden)
        }
    }

    func testCalibrationDialogsDescribeTheActualUnitAndOfferConfirmAndCancel() async throws {
        let fixture = OffsetCorrectionFixture()
        let controller = try makeController(fixture)
        let output = OffsetCorrectionOutputSpy()
        controller.output = output
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        for type in [OffsetCorrectionType.temperature, .humidity, .pressure] {
            for explicitUnit in [false, true] {
                let model = OffsetCorrectionViewModel(type: type, sensorSettings: fixture.offsets())
                model.temperatureUnit.value = explicitUnit ? .fahrenheit : nil
                model.pressureUnit.value = explicitUnit ? .inchesOfMercury : nil
                controller.viewModel = model
                controller.showCalibrateDialog()
                let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
                let message: String
                switch type {
                case .temperature:
                    message = RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterTemperature(
                        explicitUnit ? TemperatureUnit.fahrenheit.symbol : TemperatureUnit.celsius.symbol)
                case .humidity:
                    message = RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterHumidity(
                        RuuviLocalization.humidityRelativeUnit)
                case .pressure:
                    message = RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterPressure(
                        explicitUnit ? UnitPressure.inchesOfMercury.ruuviSymbol : UnitPressure.hectopascals.ruuviSymbol)
                }
                XCTAssertEqual(alert.message, message)
                XCTAssertEqual(alert.actions.map(\.title), [RuuviLocalization.confirm, RuuviLocalization.cancel])
                XCTAssertEqual(alert.actions.map(\.style), [.destructive, .cancel])
                XCTAssertEqual(alert.textFields?.first?.keyboardType, .numbersAndPunctuation)
                await dismiss(controller)
            }
        }
        controller.showClearConfirmationDialog()
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, RuuviLocalization.OffsetCorrection.Dialog.Calibration.clearConfirm)
        XCTAssertEqual(alert.actions.map(\.style), [.destructive, .cancel])
        XCTAssertEqual(alert.textFields?.count ?? 0, 0)
        await dismiss(controller)
    }

    private func dismiss(_ controller: UIViewController) async {
        await waitForAppState("alert presentation complete") {
            controller.presentedViewController?.isBeingPresented != true
        }
        await withCheckedContinuation { continuation in
            controller.dismiss(animated: false) { continuation.resume() }
        }
    }

    private func makeController(_ fixture: OffsetCorrectionFixture) throws -> OffsetCorrectionAppleViewController {
        let controller = try XCTUnwrap(
            UIStoryboard(name: "OffsetCorrection", bundle: .main)
                .instantiateInitialViewController() as? OffsetCorrectionAppleViewController)
        controller.measurementService = fixture.measurements.measurement
        return controller
    }
}

final class OffsetCorrectionOutputSpy: OffsetCorrectionViewOutput {
    var loads = 0
    var calibrateDialogs = 0
    var clearDialogs = 0
    var clears = 0
    var values = [Double]()
    func viewDidLoad() { loads += 1 }
    func viewDidOpenCalibrateDialog() { calibrateDialogs += 1 }
    func viewDidOpenClearDialog() { clearDialogs += 1 }
    func viewDidClearOffsetValue() { clears += 1 }
    func viewDidSetCorrectValue(correctValue: Double) { values.append(correctValue) }
}
