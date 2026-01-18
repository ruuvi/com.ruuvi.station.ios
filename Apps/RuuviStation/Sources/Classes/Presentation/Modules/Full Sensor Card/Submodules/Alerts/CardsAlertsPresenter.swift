import Foundation
import RuuviOntology
import RuuviService
import RuuviNotifier

final class CardsAlertsPresenter: NSObject {
    weak var view: CardsAlertsViewInput?
    weak var output: CardsAlertsPresenterOutput?

    private let measurementService: RuuviServiceMeasurement
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var snapshot: RuuviTagCardSnapshot?
    private var sensor: AnyRuuviTagSensor?
    private var sensorSettings: SensorSettings?
    private var isObservingCoordinator = false
    private lazy var alertHandler: RuuviNotifier? =
        AppAssembly.shared.assembler.resolver.resolve(RuuviNotifier.self)

    init(
        measurementService: RuuviServiceMeasurement
    ) {
        self.measurementService = measurementService
        super.init()
    }
}

// MARK: - CardsAlertsPresenterInput
extension CardsAlertsPresenter: CardsAlertsPresenterInput {
    func configure(
        with snapshots: [RuuviTagCardSnapshot],
        snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?,
        settings: SensorSettings?
    ) {
        self.snapshots = snapshots
        configure(with: snapshot, sensor: sensor, settings: settings)
    }

    func configure(
        with snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?,
        settings: SensorSettings?
    ) {
        self.snapshot = snapshot
        self.sensor = sensor
        self.sensorSettings = settings
    }

    func start() {
        startObservingCoordinator()
        syncAlertsIfNeeded()
        if let snapshot {
            view?.configure(snapshot: snapshot)
            updateAlertSections(for: snapshot)
        }
        RuuviTagServiceCoordinatorManager.shared.setAlertMuteRefreshActive(true)
    }

    func stop() {
        stopObservingCoordinator()
        RuuviTagServiceCoordinatorManager.shared.setAlertMuteRefreshActive(false)
    }

    func scroll(to index: Int, animated: Bool) {}
}

// MARK: - CardsAlertsViewOutput
extension CardsAlertsPresenter: CardsAlertsViewOutput {
    func viewDidLoad() {
        // No op.
    }

    func viewDidChangeAlertState(
        for type: AlertType,
        isOn: Bool
    ) {
        guard shouldApplyAlertStateChange(for: type, isOn: isOn) else { return }
        if case .movement = type, !isOn, let luid = sensor?.luid {
            alertHandler?.clearMovementHysteresis(for: luid.value)
        }
        withAlertService { service, snapshot, sensor in
            service.setAlertState(
                for: type,
                isOn: isOn,
                snapshot: snapshot,
                physicalSensor: sensor
            )
        }
    }

    func viewDidChangeAlertLowerBound(
        for type: AlertType,
        lower: CGFloat
    ) {
        let newValue = convertDisplayValueToServiceValue(Double(lower), for: type)
        guard shouldApplyLowerBoundChange(for: type, candidate: newValue) else { return }
        withAlertService { service, snapshot, sensor in
            service.setAlertBounds(
                for: type,
                lowerBound: newValue,
                upperBound: nil,
                snapshot: snapshot,
                physicalSensor: sensor
            )
        }
    }

    func viewDidChangeAlertUpperBound(
        for type: AlertType,
        upper: CGFloat
    ) {
        let newValue = convertDisplayValueToServiceValue(Double(upper), for: type)
        guard shouldApplyUpperBoundChange(for: type, candidate: newValue) else { return }
        withAlertService { service, snapshot, sensor in
            service.setAlertBounds(
                for: type,
                lowerBound: nil,
                upperBound: newValue,
                snapshot: snapshot,
                physicalSensor: sensor
            )
        }
    }

    func viewDidChangeCloudConnectionAlertUnseenDuration(duration: Int) {
        let seconds = Double(duration)
        guard shouldApplyCloudDelayChange(candidate: seconds) else { return }
        withAlertService { service, snapshot, sensor in
            service.setCloudConnectionUnseenDuration(
                seconds,
                snapshot: snapshot,
                physicalSensor: sensor
            )
        }
    }

    func viewDidChangeAlertDescription(
        for type: AlertType,
        description: String?
    ) {
        guard shouldApplyDescriptionChange(for: type, candidate: description) else { return }
        withAlertService { service, snapshot, sensor in
            service.setAlertDescription(
                for: type,
                description: description,
                snapshot: snapshot,
                physicalSensor: sensor
            )
        }
    }
}

// MARK: - Snapshot Observing
extension CardsAlertsPresenter: RuuviTagServiceCoordinatorObserver {
    func coordinatorDidReceiveEvent(
        _ coordinator: RuuviTagServiceCoordinator,
        event: RuuviTagServiceCoordinatorEvent
    ) {
        switch event {
        case let .snapshotsUpdated(snapshots, _, _):
            self.snapshots = snapshots
            guard let updatedSnapshot = snapshots.first(where: { matchesCurrentSnapshot($0) })
            else { return }
            processSnapshotUpdate(updatedSnapshot)
        case let .snapshotUpdated(updatedSnapshot, _),
             let .connectionSnapshotUpdated(updatedSnapshot),
             let .alertSnapshotUpdated(updatedSnapshot):
            processSnapshotUpdate(updatedSnapshot)
        default:
            break
        }
    }
}

private extension CardsAlertsPresenter {
    func processSnapshotUpdate(_ updatedSnapshot: RuuviTagCardSnapshot) {
        guard matchesCurrentSnapshot(updatedSnapshot) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.handleSnapshotUpdate(updatedSnapshot)
        }
    }

    func updateAlertSections(for snapshot: RuuviTagCardSnapshot) {
        let sections = CardsSettingsAlertsBuilder.makeSections(
            snapshot: snapshot,
            measurementService: measurementService
        )
        view?.updateAlertSections(sections)
    }

    func handleSnapshotUpdate(_ updatedSnapshot: RuuviTagCardSnapshot) {
        snapshot = updatedSnapshot
        sensor = RuuviTagServiceCoordinatorManager.shared.getSensor(for: updatedSnapshot.id)
        sensorSettings = RuuviTagServiceCoordinatorManager.shared
            .getSensorSettings(for: updatedSnapshot.id)
        view?.configure(snapshot: updatedSnapshot)
        updateAlertSections(for: updatedSnapshot)
    }

    func startObservingCoordinator() {
        guard !isObservingCoordinator else { return }
        RuuviTagServiceCoordinatorManager.shared.addObserver(self)
        isObservingCoordinator = true
    }

    func stopObservingCoordinator() {
        guard isObservingCoordinator else { return }
        RuuviTagServiceCoordinatorManager.shared.removeObserver(self)
        isObservingCoordinator = false
    }

    func matchesCurrentSnapshot(_ candidate: RuuviTagCardSnapshot) -> Bool {
        guard let snapshot else { return false }
        let sameLuid = candidate.identifierData.luid?.any != nil &&
            (candidate.identifierData.luid?.any == snapshot.identifierData.luid?.any)
        let sameMac = candidate.identifierData.mac?.any != nil &&
            (candidate.identifierData.mac?.any == snapshot.identifierData.mac?.any)
        return sameMac || sameLuid || candidate.id == snapshot.id
    }

    func withAlertService(
        _ block: (RuuviTagAlertService, RuuviTagCardSnapshot, RuuviTagSensor) -> Void
    ) {
        guard let snapshot, let sensor = sensor?.any else { return }
        RuuviTagServiceCoordinatorManager.shared.withCoordinator { coordinator in
            block(coordinator.services.alert, snapshot, sensor)
        }
    }

    func syncAlertsIfNeeded() {
        guard let snapshot, let sensor = sensor?.any else { return }
        RuuviTagServiceCoordinatorManager.shared.syncAllAlerts(
            for: snapshot,
            physicalSensor: sensor
        )
    }

    func convertDisplayValueToServiceValue(
        _ value: Double,
        for alertType: AlertType
    ) -> Double {
        switch alertType {
        case .temperature:
            let measurement = Measurement(
                value: value,
                unit: measurementService.units.temperatureUnit
            )
            return measurement.converted(to: .celsius).value
        case .dewPoint:
            let measurement = Measurement(
                value: value,
                unit: measurementService.units.temperatureUnit
            )
            return measurement.converted(to: .celsius).value
        case .pressure:
            let measurement = Measurement(
                value: value,
                unit: measurementService.units.pressureUnit
            )
            return measurement.converted(to: .hectopascals).value
        default:
            return value
        }
    }

    func shouldApplyAlertStateChange(for type: AlertType, isOn: Bool) -> Bool {
        guard let snapshot else { return false }
        if let current = snapshot.getAlertConfig(for: type)?.isActive {
            return current != isOn
        }
        return true
    }

    func shouldApplyLowerBoundChange(for type: AlertType, candidate: Double) -> Bool {
        guard let snapshot else { return false }
        if let current = snapshot.getAlertConfig(for: type)?.lowerBound {
            return abs(current - candidate) >= 0.0001
        }
        return true
    }

    func shouldApplyUpperBoundChange(for type: AlertType, candidate: Double) -> Bool {
        guard let snapshot else { return false }
        if let current = snapshot.getAlertConfig(for: type)?.upperBound {
            return abs(current - candidate) >= 0.0001
        }
        return true
    }

    func shouldApplyDescriptionChange(for type: AlertType, candidate: String?) -> Bool {
        guard let snapshot else { return false }
        let current = snapshot.getAlertConfig(for: type)?.description
        return current != candidate
    }

    func shouldApplyCloudDelayChange(candidate: Double) -> Bool {
        guard let snapshot else { return false }
        let config = snapshot.getAlertConfig(
            for: .cloudConnection(unseenDuration: 0)
        )
        if let current = config?.unseenDuration {
            return abs(current - candidate) >= 1
        }
        return true
    }
}
