import BTKit
import Foundation
import RuuviOntology
import RuuviService
@testable import station

@MainActor final class GraphFixture {
    let measurements = MeasurementFixture()
    let reactor = AppTestReactor()
    let view = GraphViewSpy()
    let interactor = GraphInteractorSpy()
    let output = GraphOutputSpy()
    let activity = SignInActivitySpy()
    let errors = OffsetErrorSpy()
    let alerts = GraphAlertSpy()
    let export = GraphExportSpy()
    let notifications = NotificationCenter()
    var bluetooth = (isEnabled: true, userDeclined: false)
    var presenter: CardsGraphPresenter!
    init() {
        presenter = CardsGraphPresenter(
            errorPresenter: errors, settings: measurements.settings, foreground: BTKit.foreground,
            ruuviReactor: reactor, activityPresenter: activity, alertPresenter: alerts,
            measurementService: measurements.measurement, exportService: export,
            alertService: measurements.alerts, background: BTKit.background, flags: measurements.flags,
            notificationCenter: notifications,
            bluetoothState: { [weak self] in
                self?.bluetooth ?? (false, false)
            })
        presenter.view = view
        presenter.interactor = interactor
        presenter.configure(output: output)
        configure()
    }
    func configure() {
        presenter.configure(
            with: [measurements.snapshot], snapshot: measurements.snapshot,
            sensor: measurements.sensor.any, settings: nil)
    }
    func cleanup() { presenter?.stop(); measurements.cleanup() }
}

final class GraphAlertSpy: AlertPresenter {
    var alerts = [AlertViewModel]()
    func showAlert(_ viewModel: AlertViewModel) { alerts.append(viewModel) }
}

final class GraphOutputSpy: CardsGraphPresenterOutput {
    var syncing = [Bool]()
    var aborted = [(String, GraphHistoryAbortSyncSource)]()
    func setGraphGattSyncInProgress(_ inProgress: Bool) { syncing.append(inProgress) }
    func graphGattSyncAborted(for snapshot: RuuviTagCardSnapshot, source: GraphHistoryAbortSyncSource) {
        aborted.append((snapshot.id, source))
    }
}

final class GraphExportSpy: RuuviServiceExport {
    struct Request {
        let format: String
        let id: String
        let version: Int
        let settings: SensorSettings?
    }
    var requests = [Request]()
    var failure: RuuviServiceError?
    var beforeExport: (() async -> Void)?
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("graph-export.csv")
    func csvLog(for uuid: String, version: Int, settings: SensorSettings?) async throws(RuuviServiceError) -> URL {
        requests.append(.init(format: "csv", id: uuid, version: version, settings: settings))
        await beforeExport?()
        if let failure { throw failure }
        return url
    }
    func xlsxLog(for uuid: String, version: Int, settings: SensorSettings?) async throws(RuuviServiceError) -> URL {
        requests.append(.init(format: "xlsx", id: uuid, version: version, settings: settings))
        await beforeExport?()
        if let failure { throw failure }
        return url.appendingPathExtension("xlsx")
    }
}
