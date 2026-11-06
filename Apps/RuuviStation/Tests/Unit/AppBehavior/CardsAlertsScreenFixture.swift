import CoreGraphics
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class CardsAlertsScreenFixture {
    let builder = AlertBuilderFixture()
    let actions = CardsSettingsActions()
    let output = CardsAlertsViewOutputSpy()
    let type = AlertType.temperature(lower: 0, upper: 20)
    let view: CardsAlertsViewController
    var host: AppViewHost?
    init() {
        builder.configure(type, lower: 0, upper: 20)
        view = CardsAlertsViewController(
            snapshot: builder.measurements.snapshot,
            measurementService: builder.measurements.measurement, shouldExpandFirstAlertByDefault: true,
            alertSettingsDisplayMode: .alerts, actions: actions)
        view.output = output
    }
    func start() throws {
        host = try AppViewHost(view)
        view.updateAlertSections(builder.sections())
        view.view.layoutIfNeeded()
    }
    func alert() async throws -> UIAlertController {
        await waitForAppState("alert editor presented") { view.presentedViewController is UIAlertController }
        return try XCTUnwrap(view.presentedViewController as? UIAlertController)
    }
    func dismiss() async {
        await withCheckedContinuation { continuation in view.dismiss(animated: false) { continuation.resume() } }
    }
    func cleanup() { host?.close(); host = nil; builder.close() }
}

final class CardsAlertsViewOutputSpy: CardsAlertsViewOutput {
    var loads = 0
    var appearances = 0
    var states = [(String, Bool)]()
    var lowers = [(String, CGFloat)]()
    var uppers = [(String, CGFloat)]()
    var delays = [Int]()
    var descriptions = [(String, String?)]()
    var destinations = [CardsAlertsDeliveryPromptDestination]()
    func viewDidLoad() { loads += 1 }
    func viewWillAppear() { appearances += 1 }
    func viewDidChangeAlertState(for type: AlertType, isOn: Bool) { states.append((type.rawValue, isOn)) }
    func viewDidChangeAlertLowerBound(for type: AlertType, lower: CGFloat) { lowers.append((type.rawValue, lower)) }
    func viewDidChangeAlertUpperBound(for type: AlertType, upper: CGFloat) { uppers.append((type.rawValue, upper)) }
    func viewDidChangeCloudConnectionAlertUnseenDuration(duration: Int) { delays.append(duration) }
    func viewDidChangeAlertDescription(for type: AlertType, description: String?) {
        descriptions.append((type.rawValue, description))
    }
    func viewDidTapAlertDeliveryPrompt(destination: CardsAlertsDeliveryPromptDestination) {
        destinations.append(destination)
    }
}
