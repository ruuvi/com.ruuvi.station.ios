import BTKit
import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class CardsBaseFixture {
    let services = CoordinatorFixture()
    let measurement = CardChildPresenterSpy()
    let graph = CardChildPresenterSpy()
    let alerts = CardChildPresenterSpy()
    let settings = CardChildPresenterSpy()
    let view = CardsBaseViewSpy()
    let output = CardsBaseOutputSpy()
    let errors = OffsetErrorSpy()
    let features = FeatureToggleService()
    var bluetooth = [(BTScannerState) -> Void]()
    var bluetoothStops = 0
    var permission = true
    var sensors = [RuuviTagSensorStruct]()
    var snapshots = [RuuviTagCardSnapshot]()
    var presenter: CardsBasePresenter!
    func start(menu: CardsMenuType = .measurement, version: Int = 5) async throws {
        sensors = [services.data.sensor("One", version: version), services.data.sensor("Two", version: version)]
        await services.start(sensors)
        snapshots = sensors.compactMap { services.manager.getSnapshot(for: $0.id) }
        XCTAssertEqual(snapshots.count, 2)
        presenter = CardsBasePresenter(
            measurementPresenter: measurement, graphPresenter: graph, alertsPresenter: alerts,
            settingsPresenter: settings,
            foreground: BTKit.foreground, ruuviCloudService: services.cloud,
            settings: services.data.measurements.settings,
            connectionPersistence: services.connections, errorPresenter: errors, featureToggleService: features,
            flags: services.data.measurements.flags, coordinatorManager: services.manager,
            observeBluetoothState: { [weak self] callback in
                self?.bluetooth.append(callback)
                return { [weak self] in self?.bluetoothStops += 1 }
            }, permissionGranted: { [weak self] in self?.permission ?? false })
        presenter.view = view
        presenter.router = output
        configure(menu: menu)
        await flushAppBindings(); await flushAppBindings()
    }
    func configure(menu: CardsMenuType = .measurement, selected: Int = 0) {
        presenter.configure(
            for: snapshots[selected], snapshots: snapshots, ruuviTagSensors: sensors.map(\.any),
            sensorSettings: [], activeMenu: menu, output: output)
    }
    func cleanup() { presenter?.dismiss(completion: nil); presenter = nil; services.cleanup(); services.data.measurements.cleanup() }
}
