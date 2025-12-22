// swiftlint:disable file_length

import Foundation
import BTKit
import RuuviOntology
import RuuviService
import RuuviPresenters
import RuuviLocal
import RuuviDaemon
import RuuviPool
import RuuviCloud
import RuuviLocalization

class CardsSettingsPresenter: NSObject, CardsSettingsPresenterInput {

    // MARK: - Dependencies
    weak var view: CardsSettingsViewInput?
    weak var output: CardsSettingsPresenterOutput?
    var router: CardsSettingsRouterInput?

    private let ruuviSensorPropertiesService: RuuviServiceSensorProperties
    private let measurementService: RuuviServiceMeasurement
    private let errorPresenter: ErrorPresenter
    private let activityPresenter: ActivityPresenter
    private let flags: RuuviLocalFlags

    private var settings: RuuviLocalSettings

    // MARK: - State
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var snapshot: RuuviTagCardSnapshot?
    private var sensor: AnyRuuviTagSensor?
    private var sensorSettings: SensorSettings?
    private var ledBrightnessSelection: RuuviOntology.RuuviLedBrightnessLevel = .defaultSelection
    private var airShellClient: RuuviAirShellClient?

    // MARK: - Subscriptions
    private var ruuviTagSensorOwnerCheckToken: NSObjectProtocol?
    private var isObservingCoordinator = false
    private lazy var connectionPersistence: RuuviLocalConnections? =
        AppAssembly.shared.assembler.resolver.resolve(RuuviLocalConnections.self)
    private lazy var localSyncState: RuuviLocalSyncState? =
        AppAssembly.shared.assembler.resolver.resolve(RuuviLocalSyncState.self)
    private lazy var background: BTBackground? =
        AppAssembly.shared.assembler.resolver.resolve(BTBackground.self)
    private lazy var ruuviPool: RuuviPool? =
        AppAssembly.shared.assembler.resolver.resolve(RuuviPool.self)
    private var firmwareVersionCheckInProgress = false
    private var keepConnectionTimer: Timer?
    private var observedCloudRequestMac: String?

    init(
        ruuviSensorPropertiesService: RuuviServiceSensorProperties,
        measurementService: RuuviServiceMeasurement,
        settings: RuuviLocalSettings,
        errorPresenter: ErrorPresenter,
        activityPresenter: ActivityPresenter,
        flags: RuuviLocalFlags
    ) {
        self.ruuviSensorPropertiesService = ruuviSensorPropertiesService
        self.measurementService = measurementService
        self.settings = settings
        self.errorPresenter = errorPresenter
        self.activityPresenter = activityPresenter
        self.flags = flags
        super.init()
    }

    // MARK: - CardsSettingsPresenterInput
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
        startObservingRuuviTagOwnerCheckResponse()
        startObservingCoordinator()
        syncAlertsIfNeeded()
        startObservingCloudRequestState()
        if let snapshot {
            view?.configure(
                snapshot: snapshot,
                dashboardSortingType: settings.dashboardSensorOrder.count == 0 ? .alphabetical : .manual
            )
            refreshVisibleMeasurementsSummary()
            view?.updateLedBrightnessSelection(ledBrightnessSelection)
            updateAlertSections(for: snapshot)
        }
        refreshFirmwareVersionIfNeeded()
        RuuviTagServiceCoordinatorManager.shared.setAlertMuteRefreshActive(true)
    }

    func stop() {
        stopObservingCoordinator()
        RuuviTagServiceCoordinatorManager.shared.setAlertMuteRefreshActive(false)
        stopObservingCloudRequestState()
        invalidateKeepConnectionTimer()
    }

    func scroll(to index: Int, animated: Bool) {
        // TODO: Implement with new menu.
    }

    func dismiss(completion: (() -> Void)?) {
        stop()
        completion?()
    }

    func shutdown() {
        ruuviTagSensorOwnerCheckToken?.invalidate()
        stopObservingCoordinator()
        RuuviTagServiceCoordinatorManager.shared.setAlertMuteRefreshActive(false)
        stopObservingCloudRequestState()
        invalidateKeepConnectionTimer()
    }
}

extension CardsSettingsPresenter: CardsSettingsViewOutput {
    func viewDidLoad() {
        // No op.
    }

    func viewDidAskToDismiss() {
        output?.cardSettingsDidDismiss(module: self)
    }

    func viewDidConfirmClaimTag() {
        guard let sensor else { return }
        router?.openOwner(ruuviTag: sensor, mode: .claim)
    }

    func viewDidTriggerChangeBackground() {
        withSensor { router?.openBackgroundSelectionView(ruuviTag: $0) }
    }

    func viewDidAskToRemoveRuuviTag() {
        withSensor { router?.openSensorRemoval(ruuviTag: $0, output: self) }
    }

    func viewDidChangeTag(name: String) {
        withSensor { sensor in
            ruuviSensorPropertiesService.set(name: name, for: sensor.any)
                .on(failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
        }
    }

    func viewDidTapOnMacAddress() {
        withSnapshot { snapshot in
            if snapshot.identifierData.mac != nil {
                view?.showMacAddressDetail()
            } else {
                viewDidTriggerFirmwareUpdateDialog()
            }
        }
    }

    func viewDidTapOnTxPower() {
        withSnapshot { snapshot in
            guard snapshot.displayData.txPower == nil else { return }
            viewDidTriggerFirmwareUpdateDialog()
        }
    }

    func viewDidTapOnMeasurementSequenceNumber() {
        withSnapshot { snapshot in
            guard snapshot.displayData.measurementSequenceNumber == nil else { return }
            viewDidTriggerFirmwareUpdateDialog()
        }
    }

    func viewDidTapOnNoValuesView() {
        viewDidTriggerFirmwareUpdateDialog()
    }

    func viewDidTapShareButton() {
        withSensor { router?.openShare(for: $0) }
    }

    func viewDidTapOnOwner() {
        guard let snapshot else { return }
        withSensor { sensor in
            if snapshot.ownership.isClaimedTag == false {
                ruuviTagSensorOwnerCheckToken?.invalidate()
                ruuviTagSensorOwnerCheckToken = nil
                router?.openOwner(ruuviTag: sensor, mode: .claim)
            } else {
                if snapshot.metadata.isOwner {
                    router?.openOwner(ruuviTag: sensor, mode: .unclaim)
                } else {
                    router?.openContest(ruuviTag: sensor)
                }
            }
        }
    }

    func viewDidTapVisibleMeasurements() {
        guard flags.showVisibilitySettings,
              let snapshot,
              let sensor = sensor,
              snapshot.metadata.isOwner else {
            return
        }
        router?.openVisibilitySettings(
            snapshot: snapshot,
            ruuviTag: sensor,
            sensorSettings: sensorSettings
        )
    }

    func viewDidTapLedBrightness() {
        router?.openLedBrightnessSettings(
            selection: nil, // TODO: Implement this when fw supports.
            firmwareVersion: snapshot?.displayData.firmwareVersion,
            snapshotId: snapshot?.id,
            onUpdateFirmware: { [weak self] in
                guard let self else { return }
                self.withSensor { sensor in
                    self.router?.openUpdateFirmware(ruuviTag: sensor)
                }
            },
            onSelection: { [weak self] selection, completion in
                guard let self else { return }
                self.applyLedBrightnessSelection(selection) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        self.ledBrightnessSelection = selection
                        self.view?.updateLedBrightnessSelection(selection)
                    case let .failure(error):
                        self.errorPresenter.present(error: error)
                    }
                    completion(result)
                }
            }
        )
    }

    func viewDidTriggerFirmwareUpdateDialog() {
        guard
            let snapshot,
            let luid = snapshot.identifierData.luid
        else {
            return
        }

        if !settings.firmwareUpdateDialogWasShown(for: luid) {
            view?.showFirmwareUpdateDialog()
        }
    }

    func viewDidConfirmFirmwareUpdate() {
        guard let sensor else { return }
        router?.openUpdateFirmware(ruuviTag: sensor)
    }

    func viewDidIgnoreFirmwareUpdateDialog() {
        view?.showFirmwareDismissConfirmationUpdateDialog()
    }

    func viewDidChangeAlertState(
        for type: AlertType,
        isOn: Bool
    ) {
        guard shouldApplyAlertStateChange(for: type, isOn: isOn) else { return }
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

    func viewDidTapTemperatureOffsetCorrection() {
        guard let sensor = sensor else { return }
        router?.openOffsetCorrection(
            type: .temperature,
            ruuviTag: sensor.any,
            sensorSettings: sensorSettings
        )
    }

    func viewDidTapHumidityOffsetCorrection() {
        guard let sensor = sensor else { return }
        router?.openOffsetCorrection(
            type: .humidity,
            ruuviTag: sensor.any,
            sensorSettings: sensorSettings
        )
    }

    func viewDidTapOnPressureOffsetCorrection() {
        guard let sensor = sensor else { return }
        router?.openOffsetCorrection(
            type: .pressure,
            ruuviTag: sensor.any,
            sensorSettings: sensorSettings
        )
    }

    func viewDidTapOnUpdateFirmware() {
        guard let sensor = sensor else { return }
        router?.openUpdateFirmware(ruuviTag: sensor.any)
    }

    func viewDidTriggerKeepConnection(isOn: Bool) {
        guard let snapshot else { return }

        if settings.cloudModeEnabled && snapshot.metadata.isCloud && isOn {
            view?.resetKeepConnectionSwitch()
            view?.showKeepConnectionCloudModeDialog()
            return
        }

        applyKeepConnection(isOn)

        if isOn {
            settings.saveHeartbeats = true
            view?.startKeepConnectionAnimatingDots()
            startKeepConnectionTimeoutTimer()
        } else {
            view?.resetKeepConnectionSwitch()
            view?.stopKeepConnectionAnimatingDots()
            invalidateKeepConnectionTimer()
        }
    }
}

extension CardsSettingsPresenter: SensorRemovalModuleOutput {
    func sensorRemovalDidRemoveTag(
        module: SensorRemovalModuleInput,
        ruuviTag: RuuviTagSensor
    ) {
        cleanupAfterSensorRemoval()

        module.dismiss(completion: { [weak self] in
            guard let self else { return }

            let remaining = RuuviTagServiceCoordinatorManager.shared.getAllSnapshots()

            let completion: () -> Void = { [weak self] in
                guard let self else { return }
                self.output?.cardSettingsDidDeleteDevice(
                    module: self,
                    ruuviTag: ruuviTag
                )
            }

            if remaining.isEmpty {
                if let router = self.router {
                    router.dismissToRoot(completion: completion)
                } else {
                    completion()
                }
            } else {
                completion()
            }
        })
    }

    func sensorRemovalDidDismiss(module: SensorRemovalModuleInput) {
        module.dismiss(completion: { [weak self] in
            guard let sSelf = self else { return }
            sSelf.output?.cardSettingsDidDismiss(module: sSelf)
        })
    }
}

extension CardsSettingsPresenter {
    private func startObservingRuuviTagOwnerCheckResponse() {
        ruuviTagSensorOwnerCheckToken?.invalidate()
        ruuviTagSensorOwnerCheckToken = nil

        ruuviTagSensorOwnerCheckToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagOwnershipCheckDidEnd,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self,
                          let userInfo = notification.userInfo,
                          let hasOwner = userInfo[RuuviTagOwnershipCheckResultKey.hasOwner] as? Bool,
                          !hasOwner
                    else {
                        return
                    }
                    sSelf.view?.showTagClaimDialog()
                }
            )
    }

    private func startObservingCoordinator() {
        guard !isObservingCoordinator else { return }
        RuuviTagServiceCoordinatorManager.shared.addObserver(self)
        isObservingCoordinator = true
    }

    private func stopObservingCoordinator() {
        guard isObservingCoordinator else { return }
        RuuviTagServiceCoordinatorManager.shared.removeObserver(self)
        isObservingCoordinator = false
    }

    private func matchesCurrentSnapshot(_ candidate: RuuviTagCardSnapshot) -> Bool {
        guard let snapshot else { return false }
        let sameLuid = candidate.identifierData.luid?.any != nil &&
            (candidate.identifierData.luid?.any == snapshot.identifierData.luid?.any)
        let sameMac = candidate.identifierData.mac?.any != nil &&
            (candidate.identifierData.mac?.any == snapshot.identifierData.mac?.any)
        return sameMac || sameLuid || candidate.id == snapshot.id
    }

    private func handleSnapshotUpdate(_ updatedSnapshot: RuuviTagCardSnapshot) {
        snapshot = updatedSnapshot
        sensor = RuuviTagServiceCoordinatorManager.shared.getSensor(for: updatedSnapshot.id)
        sensorSettings = RuuviTagServiceCoordinatorManager.shared
            .getSensorSettings(for: updatedSnapshot.id)

        if updatedSnapshot.connectionData.isConnected ||
            !updatedSnapshot.connectionData.keepConnection {
            invalidateKeepConnectionTimer()
            view?.stopKeepConnectionAnimatingDots()
        }

        if updatedSnapshot.displayData.firmwareVersion == nil {
            fetchFirmwareVersion()
        }

        let sortingType: DashboardSortingType =
            settings.dashboardSensorOrder.isEmpty ? .alphabetical : .manual
        view?.configure(
            snapshot: updatedSnapshot,
            dashboardSortingType: sortingType
        )
        refreshVisibleMeasurementsSummary()
        updateAlertSections(for: updatedSnapshot)
        startObservingCloudRequestState()
    }

    private func updateAlertSections(for snapshot: RuuviTagCardSnapshot) {
        let sections = CardsSettingsAlertsBuilder.makeSections(
            snapshot: snapshot,
            measurementService: measurementService
        )
        view?.updateAlertSections(sections)
    }

    private func cleanupAfterSensorRemoval() {
        invalidateKeepConnectionTimer()
        view?.stopKeepConnectionAnimatingDots()
        guard let snapshot else { return }

        if let luid = snapshot.identifierData.luid {
            connectionPersistence?.setKeepConnection(false, for: luid)
            NotificationCenter.default.post(
                name: .RuuviTagHeartBeatDaemonShouldRestart,
                object: nil
            )
        }

        if snapshot.metadata.isOwner {
            NotificationCenter.default.post(
                name: .RuuviTagAdvertisementDaemonShouldRestart,
                object: nil
            )

            if snapshot.connectionData.isConnected {
                NotificationCenter.default.post(
                    name: .RuuviTagHeartBeatDaemonShouldRestart,
                    object: nil
                )
            }
        }

        if let mac = snapshot.identifierData.mac {
            localSyncState?.setSyncDate(nil, for: mac)
            localSyncState?.setGattSyncDate(nil, for: mac)
            settings.setOwnerCheckDate(for: mac, value: nil)
        }

        localSyncState?.setSyncDate(nil)

        restartServiceCoordinatorSensors()
    }

    private func restartServiceCoordinatorSensors() {
        RuuviTagServiceCoordinatorManager.shared.withCoordinator { coordinator in
            coordinator.services.data.stopObservingSensors()
            coordinator.services.data.startObservingSensors()
        }
    }

    private func applyKeepConnection(_ keep: Bool) {
        guard let snapshot else { return }
        RuuviTagServiceCoordinatorManager.shared.withCoordinator { coordinator in
            coordinator.services.connection.setKeepConnection(
                keep,
                for: snapshot
            )
        }
    }

    private func startKeepConnectionTimeoutTimer() {
        invalidateKeepConnectionTimer()
        keepConnectionTimer = Timer.scheduledTimer(
            withTimeInterval: 10,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            self.invalidateKeepConnectionTimer()

            let isConnected = self.snapshot?.connectionData.isConnected ?? false
            if !isConnected {
                self.applyKeepConnection(false)
                self.view?.resetKeepConnectionSwitch()
                self.view?.showKeepConnectionTimeoutDialog()
            }
            self.view?.stopKeepConnectionAnimatingDots()
        }
    }

    private func invalidateKeepConnectionTimer() {
        keepConnectionTimer?.invalidate()
        keepConnectionTimer = nil
    }

    private func refreshFirmwareVersionIfNeeded() {
        guard let snapshot,
              snapshot.displayData.firmwareVersion == nil else { return }
        fetchFirmwareVersion()
    }

    private func fetchFirmwareVersion() {
        guard !firmwareVersionCheckInProgress,
              let sensor = sensor,
              let luid = sensor.luid else { return }

        firmwareVersionCheckInProgress = true

        guard let background else {
            firmwareVersionCheckInProgress = false
            return
        }

        let currentSensor = sensor
        view?.freezeKeepConnectionDisplay()

        background.services.gatt.firmwareRevision(
            for: self,
            uuid: luid.value,
            options: [
                .connectionTimeout(15),
                .serviceTimeout(15),
            ]
        ) { [weak self] _, result in
            guard let self else { return }

            if case let .success(version) = result {
                let updatedTag = currentSensor.with(firmwareVersion: version)
                self.ruuviPool?.update(updatedTag)
                self.sensor = updatedTag.any
            }

            DispatchQueue.main.async {
                self.firmwareVersionCheckInProgress = false
                self.view?.unfreezeKeepConnectionDisplay()
            }
        }
    }

    private func startObservingCloudRequestState() {
        guard let mac = snapshot?.identifierData.mac?.value else { return }
        if let previous = observedCloudRequestMac {
            RuuviCloudRequestStateObserverManager.shared.stopObserving(for: previous)
        }
        observedCloudRequestMac = mac
        RuuviCloudRequestStateObserverManager.shared.startObserving(for: mac) { [weak self] state in
            self?.presentActivityIndicator(with: state)
        }
    }

    private func stopObservingCloudRequestState() {
        guard let mac = observedCloudRequestMac else { return }
        RuuviCloudRequestStateObserverManager.shared.stopObserving(for: mac)
        observedCloudRequestMac = nil
    }

    private func presentActivityIndicator(with state: RuuviCloudRequestStateType) {
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
}

private extension CardsSettingsPresenter {
    func withSensor(_ block: (AnyRuuviTagSensor) -> Void) {
        guard let sensor else { return }
        block(sensor)
    }

    func withSnapshot(_ block: (RuuviTagCardSnapshot) -> Void) {
        guard let snapshot else { return }
        block(snapshot)
    }

    func applyLedBrightnessSelection(
        _ selection: RuuviOntology.RuuviLedBrightnessLevel,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let sensor else {
            completion(.failure(UnexpectedError.failedToFindRuuviTag))
            return
        }
        guard let luid = sensor.luid else {
            completion(.failure(UnexpectedError.viewModelUUIDIsNil))
            return
        }

        let client = RuuviAirShellClient()
        airShellClient = client
        client.setLedBrightness(
            uuid: luid.value,
            level: selection
        ) { [weak self] result in
            self?.airShellClient = nil
            completion(result)
        }
    }

    func refreshVisibleMeasurementsSummary() {
        guard flags.showVisibilitySettings else {
            view?.updateVisibleMeasurementsSummary(
                value: nil,
                isVisible: false
            )
            return
        }

        guard let snapshot else {
            view?.updateVisibleMeasurementsSummary(
                value: nil,
                isVisible: false
            )
            return
        }

        guard snapshot.metadata.isOwner else {
            view?.updateVisibleMeasurementsSummary(
                value: nil,
                isVisible: false
            )
            return
        }

        guard let visibility = snapshot.displayData.measurementVisibility else {
            view?.updateVisibleMeasurementsSummary(
                value: nil,
                isVisible: false
            )
            return
        }

        let availableCount = visibility.availableIndicatorCount

        if visibility.usesDefaultOrder || availableCount <= 0 {
            view?.updateVisibleMeasurementsSummary(
                value: RuuviLocalization.visibleMeasurementsUseDefault,
                isVisible: true
            )
            return
        }

        let summary = "\(min(visibility.visibleIndicatorCount, availableCount))/\(availableCount)"
        view?.updateVisibleMeasurementsSummary(
            value: summary,
            isVisible: true
        )
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

extension CardsSettingsPresenter: RuuviTagServiceCoordinatorObserver {
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

    private func processSnapshotUpdate(_ updatedSnapshot: RuuviTagCardSnapshot) {
        guard matchesCurrentSnapshot(updatedSnapshot) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.handleSnapshotUpdate(updatedSnapshot)
        }
    }
}

// swiftlint:enable file_length
