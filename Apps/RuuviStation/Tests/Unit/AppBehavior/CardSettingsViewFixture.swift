import Combine
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class CardSettingsViewFixture {
    let builder = AlertBuilderFixture()
    let actions = CardsSettingsActions()
    let output = CardSettingsViewOutputSpy()
    let view: CardsSettingsViewController
    let host: AppViewHost
    let temperature = AlertType.temperature(lower: 0, upper: 30)
    init(shortcut: Bool = false) throws {
        builder.configure(temperature, lower: 0, upper: 30)
        builder.configure(.cloudConnection(unseenDuration: 900), delay: 900)
        builder.measurements.snapshot.displayData.firmwareVersion = "1.3.0"
        view = CardsSettingsViewController(
            snapshot: builder.measurements.snapshot,
            measurementService: builder.measurements.measurement, showsAlertSections: true,
            showsAlertShortcutSection: shortcut, actions: actions)
        view.output = output
        view.configure(snapshot: builder.measurements.snapshot, dashboardSortingType: .alphabetical)
        view.updateAlertSections(builder.sections())
        host = try AppViewHost(view)
    }
    func alert() async throws -> UIAlertController {
        await waitForAppState("settings dialog presented") { view.presentedViewController is UIAlertController }
        return try XCTUnwrap(view.presentedViewController as? UIAlertController)
    }
    func dismissAlert() async {
        await withCheckedContinuation { done in view.dismiss(animated: false) { done.resume() } }
    }
    func close() { host.close(); builder.close() }
}

final class CardSettingsViewOutputSpy: CardsSettingsViewOutput {
    var loads = 0
    var events = [String]()
    var names = [String]()
    var keep = [Bool]()
    var toggles = [(AlertType, Bool)]()
    var lower = [(AlertType, CGFloat)]()
    var upper = [(AlertType, CGFloat)]()
    var descriptions = [(AlertType, String?)]()
    var delays = [Int]()
    func viewDidLoad() { loads += 1 }
    func viewDidAskToDismiss() { events.append("dismiss") }
    func viewDidConfirmClaimTag() { events.append("claim") }
    func viewDidTriggerChangeBackground() { events.append("background") }
    func viewDidAskToRemoveRuuviTag() { events.append("remove") }
    func viewDidChangeTag(name: String) { names.append(name) }
    func viewDidTapOnMacAddress() { events.append("mac") }
    func viewDidTapOnTxPower() { events.append("power") }
    func viewDidTapOnMeasurementSequenceNumber() { events.append("sequence") }
    func viewDidTapOnNoValuesView() { events.append("no-values") }
    func viewDidTapAlertsShortcut() { events.append("alerts") }
    func viewDidTapShareButton() { events.append("share") }
    func viewDidTapOnOwner() { events.append("owner") }
    func viewDidTapVisibleMeasurements() { events.append("visibility") }
    func viewDidTapLedBrightness() { events.append("led") }
    func viewDidTapNotes() { events.append("notes") }
    func viewDidTriggerFirmwareUpdateDialog() { events.append("firmware-dialog") }
    func viewDidConfirmFirmwareUpdate() { events.append("confirm-firmware") }
    func viewDidIgnoreFirmwareUpdateDialog() { events.append("ignore-firmware") }
    func viewDidChangeAlertState(for type: AlertType, isOn: Bool) { toggles.append((type, isOn)) }
    func viewDidChangeAlertLowerBound(for type: AlertType, lower: CGFloat) { self.lower.append((type, lower)) }
    func viewDidChangeAlertUpperBound(for type: AlertType, upper: CGFloat) { self.upper.append((type, upper)) }
    func viewDidChangeCloudConnectionAlertUnseenDuration(duration: Int) { delays.append(duration) }
    func viewDidChangeAlertDescription(for type: AlertType, description: String?) {
        descriptions.append((type, description))
    }
    func viewDidTapTemperatureOffsetCorrection() { events.append("temperature-offset") }
    func viewDidTapHumidityOffsetCorrection() { events.append("humidity-offset") }
    func viewDidTapOnPressureOffsetCorrection() { events.append("pressure-offset") }
    func viewDidTapOnUpdateFirmware() { events.append("firmware") }
    func viewDidTriggerKeepConnection(isOn: Bool) { keep.append(isOn) }
}
