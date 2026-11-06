// swiftlint:disable file_length

import Foundation
import BTKit
import RuuviOntology
import RuuviService
import RuuviPresenters
import RuuviLocal
import RuuviDaemon
import RuuviPool
import RuuviStorage
import RuuviCloud
import RuuviLocalization
import RuuviNotifier

class CardsSettingsPresenter: NSObject, CardsSettingsPresenterInput {

    // MARK: - Dependencies
    weak var view: CardsSettingsViewInput?
    weak var output: CardsSettingsPresenterOutput?
    var router: CardsSettingsRouterInput?

    private let ruuviSensorPropertiesService: RuuviServiceSensorProperties
    private let coordinatorManager: RuuviTagServiceCoordinatorManager
    private let notificationCenter: NotificationCenter
    private let measurementService: RuuviServiceMeasurement
    private let errorPresenter: ErrorPresenter
    private let activityPresenter: ActivityPresenter

    private var settings: RuuviLocalSettings

    // MARK: - State
    private var configurationID = UUID()
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var snapshot: RuuviTagCardSnapshot?
    private var sensor: AnyRuuviTagSensor?
    private var sensorSettings: SensorSettings?
    private var ledBrightnessSelection: RuuviOntology.RuuviLedBrightnessLevel = .defaultSelection
    var writeLedBrightness: ((String, RuuviLedBrightnessLevel, @escaping (Result<Void, Error>) -> Void) -> Void)?
    var readFirmwareRevision: ((String, @escaping (Result<String, Error>) -> Void) -> Void)?
    var keepConnectionTimeout: TimeInterval = 10
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
    private lazy var ruuviStorage: RuuviStorage? =
        AppAssembly.shared.assembler.resolver.resolve(RuuviStorage.self)
    private lazy var alertHandler: RuuviNotifier? =
        AppAssembly.shared.assembler.resolver.resolve(RuuviNotifier.self)
    private var firmwareVersionCheckInProgress = false
    private var keepConnectionTimer: Timer?
    private var observedCloudRequestMac: String?

    init(
        ruuviSensorPropertiesService: RuuviServiceSensorProperties,
        measurementService: RuuviServiceMeasurement,
        settings: RuuviLocalSettings,
        errorPresenter: ErrorPresenter,
        activityPresenter: ActivityPresenter,
        coordinatorManager: RuuviTagServiceCoordinatorManager = .shared,
        notificationCenter: NotificationCenter = .default,
        pool: RuuviPool? = nil,
        connections: RuuviLocalConnections? = nil,
        syncState: RuuviLocalSyncState? = nil,
        storage: RuuviStorage? = nil
    ) {
        self.coordinatorManager = coordinatorManager
        self.notificationCenter = notificationCenter
        self.ruuviSensorPropertiesService = ruuviSensorPropertiesService
        self.measurementService = measurementService
        self.settings = settings
        self.errorPresenter = errorPresenter
        self.activityPresenter = activityPresenter
        super.init()
        if let pool { self.ruuviPool = pool }
        if let connections { self.connectionPersistence = connections }
        if let syncState { self.localSyncState = syncState }
        if let storage { self.ruuviStorage = storage }
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
        configurationID = UUID()
        resetFirmwareCheck()
        self.snapshot = snapshot
        self.sensor = sensor
        self.sensorSettings = settings
    }

    func start() {
        startObservingRuuviTagOwnerCheckResponse()
        startObservingCoordinator()
        refreshConnectionStateIfNeeded()
        syncAlertsIfNeeded()
        startObservingCloudRequestState()
        if let snapshot {
            ledBrightnessSelection =
                settings.ledBrightnessSelection(
                    for: ledBrightnessMacId()
                ) ?? .defaultSelection
            view?.configure(
                snapshot: snapshot,
                dashboardSortingType: settings.dashboardSensorOrder.count == 0 ? .alphabetical : .manual
            )
            refreshVisibleMeasurementsSummary()
            refreshNotesSummary()
            view?.updateLedBrightnessSelection(ledBrightnessSelection)
            updateAlertSections(for: snapshot)
        }
        refreshFirmwareVersionIfNeeded()
        coordinatorManager.setAlertMuteRefreshActive(true)
    }

    func stop() {
        configurationID = UUID()
        resetFirmwareCheck()
        stopObservingOwnerCheck()
        stopObservingCoordinator()
        coordinatorManager.setAlertMuteRefreshActive(false)
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

    func shutdown() { stop() }

    deinit { stop() }

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
        guard let snapshot else { return }
        coordinatorManager.updateSensorName(name, for: snapshot)
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

    func viewDidTapAlertsShortcut() {
        output?.cardSettingsDidRequestOpenAlerts(module: self)
    }

    func viewDidTapShareButton() {
        withSensor { router?.openShare(for: $0) }
    }

    func viewDidTapOnOwner() {
        guard let snapshot else { return }
        withSensor { sensor in
            if snapshot.ownership.isClaimedTag == false {
                stopObservingOwnerCheck()
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
        guard let snapshot,
            let sensor = sensor,
            snapshot.metadata.canEditLocalSettings
        else {
            return
        }
        router?.openVisibilitySettings(
            snapshot: snapshot,
            ruuviTag: sensor,
            sensorSettings: sensorSettings
        )
    }

    func viewDidTapLedBrightness() {
        let mac = ledBrightnessMacId()
        let currentSelection = settings.ledBrightnessSelection(for: mac) ?? ledBrightnessSelection
        let context = configurationID
        let sensor = sensor
        ledBrightnessSelection = currentSelection
        router?.openLedBrightnessSettings(
            selection: currentSelection,
            firmwareVersion: snapshot?.displayData.firmwareVersion,
            snapshotId: snapshot?.id,
            onUpdateFirmware: { [weak self] in
                guard let sensor else { return }
                self?.router?.openUpdateFirmware(ruuviTag: sensor)
            },
            onSelection: { [weak self, settings = settings] selection, completion in
                guard let self else {
                    completion(.failure(UnexpectedError.callerDeinitedDuringOperation))
                    return
                }
                let previous = settings.ledBrightnessSelection(for: mac) ?? currentSelection
                self.applyLedBrightnessSelection(selection, sensor: sensor) { [weak self] result in
                    let displayed: RuuviLedBrightnessLevel
                    switch result {
                    case .success:
                        settings.setLedBrightnessSelection(selection, for: mac)
                        displayed = selection
                    case .failure:
                        displayed = previous
                    }
                    if let self, self.configurationID == context {
                        self.ledBrightnessSelection = displayed
                        self.view?.updateLedBrightnessSelection(displayed)
                    }
                    completion(result)
                }
            }
        )
    }

    func viewDidTapNotes() {
        guard let snapshot, snapshot.metadata.canEditLocalSettings else {
            return
        }

        router?.openNotesSettings(
            notes: sensorSettings?.description,
            onSave: { [weak self] notes, completion in
                self?.updateNotes(notes, completion: completion)
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

            let remaining = coordinatorManager.getAllSnapshots()

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
    private func stopObservingOwnerCheck() {
        if let token = ruuviTagSensorOwnerCheckToken { notificationCenter.removeObserver(token) }
        ruuviTagSensorOwnerCheckToken = nil
    }

    private func startObservingRuuviTagOwnerCheckResponse() {
        stopObservingOwnerCheck()

        ruuviTagSensorOwnerCheckToken = notificationCenter
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
        coordinatorManager.addObserver(self)
        isObservingCoordinator = true
    }

    private func stopObservingCoordinator() {
        guard isObservingCoordinator else { return }
        coordinatorManager.removeObserver(self)
        isObservingCoordinator = false
    }

    private func matchesCurrentSnapshot(_ candidate: RuuviTagCardSnapshot) -> Bool {
        guard let snapshot else { return false }
        let sameLuid =
            candidate.identifierData.luid?.any != nil
            && (candidate.identifierData.luid?.any == snapshot.identifierData.luid?.any)
        let sameMac =
            candidate.identifierData.mac?.any != nil
            && (candidate.identifierData.mac?.any == snapshot.identifierData.mac?.any)
        return sameMac || sameLuid || candidate.id == snapshot.id
    }

    private func handleSnapshotUpdate(_ updatedSnapshot: RuuviTagCardSnapshot) {
        snapshot = updatedSnapshot
        sensor = coordinatorManager.getSensor(for: updatedSnapshot.id)
        sensorSettings = coordinatorManager
            .getSensorSettings(for: updatedSnapshot.id)
        refreshConnectionStateIfNeeded()

        if updatedSnapshot.connectionData.isConnected || !updatedSnapshot.connectionData.keepConnection {
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
        refreshNotesSummary()
        updateAlertSections(for: updatedSnapshot)
        startObservingCloudRequestState()
    }

    private func updateAlertSections(for snapshot: RuuviTagCardSnapshot) {
        let sensorId = sensor?.id ?? snapshot.id
        let customRanges = CardsSettingsAlertsBuilder.CustomRangeSelection(
            temperature: settings.showCustomTempAlertBound(for: sensorId),
            carbonDioxide: settings.showCustomCO2AlertBound(for: sensorId),
            particulateMatter: settings.showCustomPMAlertBound(for: sensorId)
        )
        let sections = CardsSettingsAlertsBuilder.makeSections(
            snapshot: snapshot,
            measurementService: measurementService,
            customRanges: customRanges
        )
        view?.updateAlertSections(sections)
    }

    private func cleanupAfterSensorRemoval() {
        invalidateKeepConnectionTimer()
        view?.stopKeepConnectionAnimatingDots()
        guard let snapshot else { return }

        if let luid = snapshot.identifierData.luid {
            connectionPersistence?.setKeepConnection(false, for: luid)
            notificationCenter.post(
                name: .RuuviTagHeartBeatDaemonShouldRestart,
                object: nil
            )
        }

        if snapshot.metadata.isOwner {
            notificationCenter.post(
                name: .RuuviTagAdvertisementDaemonShouldRestart,
                object: nil
            )

            if snapshot.connectionData.isConnected {
                notificationCenter.post(
                    name: .RuuviTagHeartBeatDaemonShouldRestart,
                    object: nil
                )
            }
        }

        if let mac = snapshot.identifierData.mac {
            localSyncState?.setSyncDate(nil, for: mac)
            localSyncState?.setGattSyncDate(nil, for: mac)
            localSyncState?.setAutoGattSyncAttemptDate(nil, for: mac)
            settings.setOwnerCheckDate(for: mac, value: nil)
        }

        localSyncState?.setSyncDate(nil)

        restartServiceCoordinatorSensors()
    }

    private func restartServiceCoordinatorSensors() {
        coordinatorManager.withCoordinator { coordinator in
            coordinator.services.data.stopObservingSensors()
            coordinator.services.data.startObservingSensors()
        }
    }

    private func applyKeepConnection(_ keep: Bool) {
        guard let snapshot else { return }
        coordinatorManager.withCoordinator { coordinator in
            coordinator.services.connection.setKeepConnection(
                keep,
                for: snapshot
            )
        }
    }

    private func startKeepConnectionTimeoutTimer() {
        invalidateKeepConnectionTimer()
        keepConnectionTimer = Timer.scheduledTimer(
            withTimeInterval: keepConnectionTimeout,
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
            snapshot.displayData.firmwareVersion == nil
        else { return }
        fetchFirmwareVersion()
    }

    private func fetchFirmwareVersion() {
        guard !firmwareVersionCheckInProgress,
            let sensor, let luid = sensor.luid else { return }
        let context = configurationID
        let completion: (Result<String, Error>) -> Void = { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.configurationID == context else { return }
                defer { if self.configurationID == context { self.resetFirmwareCheck() } }
                guard case let .success(version) = result else { return }
                let latest = (try? await self.ruuviStorage?.readOne(sensor.id)) ?? sensor
                guard self.configurationID == context else { return }
                let updated = latest.with(firmwareVersion: version)
                _ = try? await self.ruuviPool?.update(updated)
                guard self.configurationID == context else { return }
                self.sensor = updated.any
            }
        }
        if let readFirmwareRevision {
            firmwareVersionCheckInProgress = true
            view?.freezeKeepConnectionDisplay()
            readFirmwareRevision(luid.value, completion)
        } else if let background {
            firmwareVersionCheckInProgress = true
            view?.freezeKeepConnectionDisplay()
            background.services.gatt.firmwareRevision(
                for: self, uuid: luid.value,
                options: [.connectionTimeout(15), .serviceTimeout(15)]
            ) { _, result in completion(result.mapError { $0 as Error }) }
        }
    }

    private func resetFirmwareCheck() {
        guard firmwareVersionCheckInProgress else { return }
        firmwareVersionCheckInProgress = false
        view?.unfreezeKeepConnectionDisplay()
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
    func ledBrightnessMacId() -> MACIdentifier? {
        snapshot?.identifierData.mac ?? sensor?.macId
    }

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
        sensor: AnyRuuviTagSensor?,
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

        if let writeLedBrightness {
            writeLedBrightness(luid.value, selection, completion)
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
        guard let snapshot else {
            view?.updateVisibleMeasurementsSummary(
                value: nil,
                isVisible: false
            )
            return
        }

        guard snapshot.metadata.canEditLocalSettings else {
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

    func refreshNotesSummary() {
        let isEditable = snapshot?.metadata.canEditLocalSettings ?? false
        view?.updateNotes(
            value: sensorSettings?.description,
            isEditable: isEditable
        )
    }

    func updateNotes(_ notes: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let sensor = sensor?.any else {
            completion(.failure(UnexpectedError.failedToFindRuuviTag))
            return
        }
        let value = notes.flatMap { $0.isEmpty ? nil : String($0.prefix(1000)) }
        let context = configurationID
        activityPresenter.show(with: .loading(message: nil))
        Task { @MainActor [weak self, service = ruuviSensorPropertiesService, pool = ruuviPool,
                          activity = activityPresenter] in
            defer { activity.dismiss() }
            do {
                let settings = try await service.updateDescription(for: sensor, description: value)
                if let self, self.configurationID == context {
                    self.sensorSettings = settings
                    self.refreshNotesSummary()
                }
                completion(.success(()))
            } catch {
                if case RuuviServiceError.ruuviCloud = error {
                    // The local write succeeded. Preserve it even if cloud synchronization failed.
                    if let pool {
                        do {
                            let settings = try await pool.readSensorSettings(sensor)
                            if let self, self.configurationID == context {
                                self.sensorSettings = settings
                                self.refreshNotesSummary()
                            }
                        } catch {
                            // Keep the last displayed note if rereading local settings also fails.
                        }
                    }
                    activity.update(with: .failed(message: RuuviLocalization.activitySavingFail))
                    completion(.success(()))
                } else {
                    if let self, self.configurationID == context { self.errorPresenter.present(error: error) }
                    completion(.failure(error))
                }
            }
        }
    }

    func withAlertService(
        _ block: (RuuviTagAlertService, RuuviTagCardSnapshot, RuuviTagSensor) -> Void
    ) {
        guard let snapshot, let sensor = sensor?.any else { return }
        coordinatorManager.withCoordinator { coordinator in
            block(coordinator.services.alert, snapshot, sensor)
        }
    }

    func syncAlertsIfNeeded() {
        guard let snapshot, let sensor = sensor?.any else { return }
        coordinatorManager.syncAllAlerts(
            for: snapshot,
            physicalSensor: sensor
        )
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

    private func processSnapshotUpdate(_ updatedSnapshot: RuuviTagCardSnapshot) {
        guard matchesCurrentSnapshot(updatedSnapshot) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.handleSnapshotUpdate(updatedSnapshot)
        }
    }

    private func refreshCurrentSnapshot() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let snapshot = self.snapshot else { return }
            self.refreshConnectionStateIfNeeded()
            self.updateAlertSections(for: snapshot)
        }
    }
}

// swiftlint:enable file_length
