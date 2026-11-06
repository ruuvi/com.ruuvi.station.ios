// swiftlint:disable file_length

import Foundation
import RuuviCloud
import RuuviLocalization
import RuuviLocal
import RuuviNotifier
import RuuviOntology
import RuuviPresenters
import RuuviService

final class CardsAlertsPresenter: NSObject {
    weak var view: CardsAlertsViewInput?
    weak var output: CardsAlertsPresenterOutput?

    private let measurementService: RuuviServiceMeasurement
    private let activityPresenter: ActivityPresenter
    private let settings: RuuviLocalSettings
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var snapshot: RuuviTagCardSnapshot?
    private var sensor: AnyRuuviTagSensor?
    private var sensorSettings: SensorSettings?
    private var observationGeneration = UUID()
    private var isObservingCoordinator = false
    private var observedCloudRequestMac: String?
    private let coordinatorManager: RuuviTagServiceCoordinatorManager
    private let alertHandler: RuuviNotifier?

    init(
        measurementService: RuuviServiceMeasurement,
        activityPresenter: ActivityPresenter,
        settings: RuuviLocalSettings,
        coordinatorManager: RuuviTagServiceCoordinatorManager = .shared,
        alertHandler: RuuviNotifier? = nil
    ) {
        self.measurementService = measurementService
        self.activityPresenter = activityPresenter
        self.settings = settings
        self.coordinatorManager = coordinatorManager
        self.alertHandler = alertHandler ?? AppAssembly.shared.assembler.resolver.resolve(RuuviNotifier.self)
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
        observationGeneration = UUID()
        self.snapshot = snapshot
        self.sensor = sensor
        self.sensorSettings = settings
        if isObservingCoordinator { startObservingCloudRequestState() }
    }

    func start() {
        startObservingCoordinator()
        refreshConnectionStateIfNeeded()
        syncAlertsIfNeeded()
        startObservingCloudRequestState()
        if let snapshot {
            view?.configure(snapshot: snapshot)
            updateAlertSections(for: snapshot)
            updateAlertDeliveryPrompt(for: snapshot)
        }
        coordinatorManager.setAlertMuteRefreshActive(true)
    }

    func stop() {
        stopObservingCoordinator()
        stopObservingCloudRequestState()
        coordinatorManager.setAlertMuteRefreshActive(false)
    }

    func scroll(to index: Int, animated: Bool) {}
}

// MARK: - CardsAlertsViewOutput
extension CardsAlertsPresenter: CardsAlertsViewOutput {
    func viewDidLoad() {
        // No op.
    }

    func viewWillAppear() {
        guard let snapshot else { return }
        updateAlertDeliveryPrompt(for: snapshot)
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

    func viewDidTapAlertDeliveryPrompt(
        destination: CardsAlertsDeliveryPromptDestination
    ) {
        output?.cardsAlerts(
            module: self,
            didRequest: destination
        )
    }
}

// MARK: - Snapshot Observing
extension CardsAlertsPresenter: RuuviTagServiceCoordinatorObserver {
    func coordinatorDidReceiveEvent(
        _ coordinator: RuuviTagServiceCoordinator,
        event: RuuviTagServiceCoordinatorEvent
    ) {
        guard isObservingCoordinator else { return }
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
        case .bluetoothStateChanged,
             .cloudModeChanged,
             .cloudSyncCompleted,
             .userLoginStateChanged,
             .userLogoutStateChanged,
             .alertsChanged:
            refreshCurrentSnapshot()
        default:
            break
        }
    }
}

private extension CardsAlertsPresenter {
    func processSnapshotUpdate(_ updatedSnapshot: RuuviTagCardSnapshot) {
        guard isObservingCoordinator, matchesCurrentSnapshot(updatedSnapshot) else { return }
        let generation = observationGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isObservingCoordinator, self.observationGeneration == generation,
                  self.matchesCurrentSnapshot(updatedSnapshot) else { return }
            self.handleSnapshotUpdate(updatedSnapshot)
        }
    }

    func refreshCurrentSnapshot() {
        let generation = observationGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isObservingCoordinator, self.observationGeneration == generation,
                  let snapshot = self.snapshot else { return }
            self.refreshConnectionStateIfNeeded()
            self.updateAlertSections(for: snapshot)
            self.updateAlertDeliveryPrompt(for: snapshot)
        }
    }

    func updateAlertSections(for snapshot: RuuviTagCardSnapshot) {
        let sections = CardsSettingsAlertsBuilder.makeSections(
            snapshot: snapshot,
            measurementService: measurementService
        )
        view?.updateAlertSections(sections)
    }

    func updateAlertDeliveryPrompt(for snapshot: RuuviTagCardSnapshot) {
        view?.updateAlertDeliveryPrompt(
            CardsAlertsDeliveryPrompt.make(
                for: snapshot,
                isBackgroundScanningEnabled: settings.saveHeartbeats
            )
        )
    }

    func handleSnapshotUpdate(_ updatedSnapshot: RuuviTagCardSnapshot) {
        snapshot = updatedSnapshot
        sensor = coordinatorManager.getSensor(for: updatedSnapshot.id)
        sensorSettings = coordinatorManager
            .getSensorSettings(for: updatedSnapshot.id)
        refreshConnectionStateIfNeeded()
        view?.configure(snapshot: updatedSnapshot)
        updateAlertSections(for: updatedSnapshot)
        updateAlertDeliveryPrompt(for: updatedSnapshot)
    }

    func startObservingCoordinator() {
        guard !isObservingCoordinator else { return }
        coordinatorManager.addObserver(self)
        isObservingCoordinator = true
    }

    func stopObservingCoordinator() {
        guard isObservingCoordinator else { return }
        observationGeneration = UUID()
        coordinatorManager.removeObserver(self)
        isObservingCoordinator = false
    }

    func startObservingCloudRequestState() {
        stopObservingCloudRequestState()
        guard let mac = snapshot?.identifierData.mac?.value else { return }
        observedCloudRequestMac = mac
        RuuviCloudRequestStateObserverManager.shared.startObserving(for: mac) { [weak self] state in
            guard let self, self.isObservingCoordinator, self.observedCloudRequestMac == mac else { return }
            self.presentActivityIndicator(with: state)
        }
    }

    func stopObservingCloudRequestState() {
        guard let mac = observedCloudRequestMac else { return }
        RuuviCloudRequestStateObserverManager.shared.stopObserving(for: mac)
        observedCloudRequestMac = nil
    }

    func presentActivityIndicator(with state: RuuviCloudRequestStateType) {
        switch state {
        case .loading:
            activityPresenter.show(
                with: .loading(
                    message: RuuviLocalization.activitySavingToCloud
                )
            )
        case .success:
            activityPresenter.update(
                with: .success(
                    message: RuuviLocalization.activitySavingSuccess
                )
            )
        case .failed:
            activityPresenter.update(
                with: .failed(
                    message: RuuviLocalization.activitySavingFail
                )
            )
        case .complete:
            activityPresenter.dismiss()
        }
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
        coordinatorManager.withCoordinator { coordinator in
            block(coordinator.services.alert, snapshot, sensor)
        }
    }

    @discardableResult
    func refreshConnectionStateIfNeeded() -> Bool {
        guard let snapshot, snapshot.identifierData.luid != nil else {
            return false
        }

        let status = coordinatorManager
            .getConnectionStatus(for: snapshot)
        return snapshot.updateConnectionData(
            isConnected: status.isConnected,
            isConnectable: snapshot.connectionData.isConnectable,
            keepConnection: status.keepConnection
        )
    }

    func syncAlertsIfNeeded() {
        guard let snapshot, let sensor = sensor?.any else { return }
        coordinatorManager.syncAllAlerts(
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
        guard candidate >= Double(RuuviAlertConstants.CloudConnection.minUnseenDurationSeconds) else {
            return false
        }
        let config = snapshot.getAlertConfig(
            for: .cloudConnection(unseenDuration: 0)
        )
        if let current = config?.unseenDuration {
            return abs(current - candidate) >= 1
        }
        return true
    }
}
