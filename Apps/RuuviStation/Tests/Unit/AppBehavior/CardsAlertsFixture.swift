import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class CardsAlertsFixture {
    let services = CoordinatorFixture()
    let view = CardsAlertsViewSpy()
    let activity = AccountActivitySpy()
    let output = CardsAlertsOutputSpy()
    let sensor: RuuviTagSensorStruct
    var snapshot: RuuviTagCardSnapshot!
    var presenter: CardsAlertsPresenter!
    init() {
        sensor = services.data.measurements.sensor
        services.data.sensors.append(sensor)
        presenter = CardsAlertsPresenter(
            measurementService: services.data.measurements.measurement,
            activityPresenter: activity, settings: services.data.measurements.settings,
            coordinatorManager: services.manager, alertHandler: services.notifier)
        presenter.view = view
        presenter.output = output
    }
    func start() async throws {
        await services.start([sensor])
        snapshot = try XCTUnwrap(services.manager.getSnapshot(for: sensor.id))
        snapshot.latestRawRecord = services.data.measurements.record()
        presenter.configure(with: [snapshot], snapshot: snapshot, sensor: sensor.any, settings: nil)
        presenter.start()
        await flushAppBindings(); await flushAppBindings()
    }
    func cleanup() { presenter.stop(); presenter = nil; services.cleanup(); services.data.measurements.cleanup() }
}

final class CardsAlertsViewSpy: CardsAlertsViewInput {
    var configured = [String]()
    var sections = [[CardsSettingsAlertSectionModel]]()
    var prompts = [CardsAlertsDeliveryPrompt?]()
    func configure(snapshot: RuuviTagCardSnapshot) { configured.append(snapshot.id) }
    func updateAlertSections(_ sections: [CardsSettingsAlertSectionModel]) { self.sections.append(sections) }
    func updateAlertDeliveryPrompt(_ prompt: CardsAlertsDeliveryPrompt?) { prompts.append(prompt) }
}

final class CardsAlertsOutputSpy: CardsAlertsPresenterOutput {
    var destinations = [CardsAlertsDeliveryPromptDestination]()
    func cardsAlerts(module: CardsAlertsPresenterInput, didRequest destination: CardsAlertsDeliveryPromptDestination) {
        destinations.append(destination)
    }
}
