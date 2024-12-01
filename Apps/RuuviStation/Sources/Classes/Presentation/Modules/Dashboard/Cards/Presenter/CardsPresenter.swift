// swiftlint:disable file_length
import BTKit
import CoreBluetooth
import Foundation
import RuuviCore
import RuuviDaemon
import RuuviLocal
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import UIKit

class CardsPresenter {
    weak var view: CardsViewInput?
    var router: CardsRouterInput!
    var interactor: CardsInteractorInput!
    var errorPresenter: ErrorPresenter!
    var settings: RuuviLocalSettings!
    var ruuviReactor: RuuviReactor!
    var alertService: RuuviServiceAlert!
    var alertHandler: RuuviNotifier!
    var foreground: BTForeground!
    var background: BTBackground!
    var connectionPersistence: RuuviLocalConnections!
    var featureToggleService: FeatureToggleService!
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!
    var localSyncState: RuuviLocalSyncState!
    var ruuviStorage: RuuviStorage!
    var permissionPresenter: PermissionPresenter!
    var permissionsManager: RuuviCorePermission!

    // MARK: - PRIVATE VARIABLES

    /// Collection of the sensor
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettings = [SensorSettings]()
    /// Collection of the card view model.
    private var viewModels: [CardsViewModel] = [] {
        didSet {
            guard let view else { return }
            view.viewModels = viewModels
        }
    }

    /// Index for visible card
    private var visibleViewModelIndex: Int = 0 {
        didSet {
            currentVisibleViewModel = viewModels[visibleViewModelIndex]
            guard let view, shouldTriggerScroll else { return }
            view.scrollIndex = visibleViewModelIndex
        }
    }

    private var currentVisibleViewModel: CardsViewModel?

    /// Whether bluetooth permission is already granted.
    private var isBluetoothPermissionGranted: Bool {
        CBCentralManager.authorization == .allowedAlways
    }

    private var mutedTillTimer: Timer?
    /// Should open chart after view is presented.
    private var shouldOpenChart: Bool = false
    private var shouldTriggerScroll: Bool = false
    private weak var tagCharts: TagChartsViewModuleInput?
    private weak var tagChartsModule: UIViewController?
    private weak var output: CardsModuleOutput?

    // MARK: - OBSERVERS

    private var ruuviTagToken: RuuviReactorToken?
    private var ruuviTagObserveLastRecordTokens = [RuuviReactorToken]()
    private var advertisementTokens = [ObservationToken]()
    private var heartbeatTokens = [ObservationToken]()
    private var sensorSettingsTokens = [RuuviReactorToken]()
    private var stateToken: ObservationToken?
    private var backgroundToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var ruuviTagAdvertisementDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagPropertiesDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagHeartbeatDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagReadLogsOperationFailureToken: NSObjectProtocol?
    private var startKeepingConnectionToken: NSObjectProtocol?
    private var stopKeepingConnectionToken: NSObjectProtocol?
    private var readRSSIToken: NSObjectProtocol?
    private var readRSSIIntervalToken: NSObjectProtocol?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var cloudModeToken: NSObjectProtocol?
    private var sensorOrderChangeToken: NSObjectProtocol?

    func dismiss(completion: (() -> Void)?) {
        shutdownModule()
        completion?()
    }

    deinit {
        shutdownModule()
    }
}

// MARK: - CardsModuleInput

extension CardsPresenter: CardsModuleInput {
    func configure(
        viewModels: [CardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings]
    ) {
        self.viewModels = viewModels
        ruuviTags = ruuviTagSensors
        self.sensorSettings = sensorSettings
    }

    func configure(output: CardsModuleOutput) {
        self.output = output
    }

    func configure(
        scrollTo: CardsViewModel?,
        openChart: Bool
    ) {
        updateVisibleCard(
            from: scrollTo,
            openChart: openChart,
            triggerScroll: true
        )
    }
}

extension CardsPresenter {
    private func startObservingVisibleTag() {
        startObservingRuuviTags()
        observeSensorSettings()
        observeRuuviTagBTMesurements()
        startListeningLatestRecords()
        startListeningToRuuviTagsAlertStatus()
        startObservingAlertChanges()
        startObservingBackgroundChanges()
        startObservingDaemonsErrors()
        startObservingDidConnectDisconnectNotifications()
        startObservingCloudModeNotification()
        reloadMutedTill()
    }

    private func startObservingAppState() {
        NotificationCenter
            .default
            .addObserver(
                self,
                selector: #selector(handleAppEnterForgroundState),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
    }

    @objc private func handleAppEnterForgroundState() {
        view?.scroll(to: visibleViewModelIndex)
    }

    private func updateVisibleCard(
        from viewModel: CardsViewModel?,
        openChart: Bool = false,
        triggerScroll: Bool = false
    ) {
        if let index = viewModels.firstIndex(where: {
            ($0.luid.value != nil && $0.luid.value == viewModel?.luid.value) ||
                ($0.mac.value != nil && $0.mac.value == viewModel?.mac.value)
        }) {
            shouldTriggerScroll = triggerScroll
            visibleViewModelIndex = index
            shouldOpenChart = openChart
            if shouldOpenChart {
                showTagCharts(for: viewModel)
            }
        }

        startObservingVisibleTag()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func startObservingRuuviTags() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            guard let sSelf = self else { return }
            switch change {
            case let .insert(sensor):
                sSelf.notifyRestartAdvertisementDaemon()
                sSelf.notifyRestartHeartBeatDaemon()
                sSelf.checkFirmwareVersion(for: sensor)
                sSelf.ruuviTags.append(sensor.any)
                sSelf.syncViewModels()
                if let viewModel = sSelf.viewModels.first(where: {
                    ($0.luid.value != nil && $0.luid.value == sensor.luid?.any)
                        || ($0.mac.value != nil && $0.mac.value == sensor.macId?.any)
                }) {
                    sSelf.updateVisibleCard(
                        from: viewModel,
                        triggerScroll: true
                    )
                    sSelf.view?.scroll(to: sSelf.visibleViewModelIndex)
                }
            case let .update(sensor):
                guard let sSelf = self else { return }
                if let index = sSelf.ruuviTags
                    .firstIndex(
                        where: {
                            ($0.macId != nil && $0.macId?.any == sensor.macId?.any)
                                || ($0.luid != nil && $0.luid?.any == sensor.luid?.any)
                        }) {
                    sSelf.ruuviTags[index] = sensor
                    sSelf.syncViewModels()
                    if let viewModel = sSelf.viewModels.first(where: {
                        ($0.luid.value != nil && $0.luid.value == sensor.luid?.any)
                            || ($0.mac.value != nil && $0.mac.value == sensor.macId?.any)
                    }) {
                        sSelf.updateVisibleCard(
                            from: viewModel,
                            triggerScroll: true
                        )
                        sSelf.view?.scroll(to: sSelf.visibleViewModelIndex)
                    }
                }

            case let .delete(sensor):
                sSelf.ruuviTags.removeAll(where: { $0.id == sensor.id })
                sSelf.syncViewModels()
                // If a sensor is deleted, and there's no more sensor take
                // user to dashboard.
                guard sSelf.viewModels.count > 0
                else {
                    sSelf.viewShouldDismiss()
                    return
                }

                // If the visible sensor is deleted, sroll to the first sensor
                // in the list and make it visible sensor.
                // Don't change scroll position if a sensor is deleted(via sync or otherwise)
                // which is not the currently visible one.
                if let first = sSelf.viewModels.first {
                    sSelf.updateVisibleCard(from: first, triggerScroll: true)
                    sSelf.view?.scroll(to: sSelf.visibleViewModelIndex)
                }
            case let .error(error):
                sSelf.errorPresenter.present(error: error)
            default: break
            }
        }
    }

    private func startListeningLatestRecords() {
        ruuviTagObserveLastRecordTokens.forEach { $0.invalidate() }
        ruuviTagObserveLastRecordTokens.removeAll()
        for viewModel in viewModels {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
                let token = ruuviReactor.observeLatest(ruuviTagSensor) { [weak self] changes in
                    if case let .update(anyRecord) = changes,
                       let viewModel = self?.viewModels
                           .first(where: {
                               ($0.luid.value != nil && ($0.luid.value == anyRecord?.luid?.any))
                                   || ($0.mac.value != nil && ($0.mac.value == anyRecord?.macId?.any))
                           }),
                           let record = anyRecord {
                        let sensorSettings = self?.sensorSettings
                            .first(where: {
                                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid.value)
                                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac.value)
                            })
                        let sensorRecord = record.with(sensorSettings: sensorSettings)
                        viewModel.update(sensorRecord)
                        self?.notifyUpdate(for: viewModel)

                        self?.processAlert(record: sensorRecord, viewModel: viewModel)
                    }
                }
                ruuviTagObserveLastRecordTokens.append(token)
            }
        }
    }

    private func startListeningToRuuviTagsAlertStatus() {
        ruuviTags.forEach { ruuviTag in
            if ruuviTag.isCloud {
                if let macId = ruuviTag.macId {
                    alertHandler.subscribe(self, to: macId.value)
                }
            } else {
                if let luid = ruuviTag.luid {
                    alertHandler.subscribe(self, to: luid.value)
                } else if let macId = ruuviTag.macId {
                    alertHandler.subscribe(self, to: macId.value)
                }
            }
        }
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken?.invalidate()
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviServiceAlertDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self else { return }
                    if let userInfo = notification.userInfo {
                        if let physicalSensor
                            = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                            let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
                            sSelf.viewModels.filter {
                                ($0.luid.value != nil && ($0.luid.value == physicalSensor.luid?.any))
                                    || ($0.mac.value != nil && ($0.mac.value == physicalSensor.macId?.any))
                            }.forEach { viewModel in
                                if sSelf.alertService.hasRegistrations(for: physicalSensor) {
                                    viewModel.alertState.value = .registered
                                } else {
                                    viewModel.alertState.value = .empty
                                }
                                sSelf.updateIsOnState(
                                    of: type,
                                    for: physicalSensor.id,
                                    viewModel: viewModel
                                )
                                sSelf.updateMutedTill(
                                    of: type,
                                    for: physicalSensor.id,
                                    viewModel: viewModel
                                )
                                self?.notifyUpdate(for: viewModel)
                            }
                        }
                    }
                }
            )
    }

    private func startMutedTillTimer() {
        mutedTillTimer = Timer
            .scheduledTimer(
                withTimeInterval: 5,
                repeats: true
            ) { [weak self] timer in
                guard let sSelf = self else { timer.invalidate(); return }
                sSelf.reloadMutedTill()
            }
    }

    private func observeRuuviTagBTMesurements() {
        advertisementTokens.forEach { $0.invalidate() }
        advertisementTokens.removeAll()
        heartbeatTokens.forEach { $0.invalidate() }
        heartbeatTokens.removeAll()

        for viewModel in viewModels {
            let skip = settings.cloudModeEnabled && viewModel.isCloud.value.bound
            if skip {
                continue
            }
            if viewModel.type == .ruuvi,
               let luid = viewModel.luid.value {
                advertisementTokens.append(foreground.observe(
                    self,
                    uuid: luid.value,
                    closure: { [weak self] _, device in
                        if let tag = device.ruuvi?.tag {
                            self?.handleMeasurementPoint(
                                tag: tag,
                                source: .advertisement
                            )
                        }
                    }
                ))

                heartbeatTokens.append(background.observe(
                    self,
                    uuid: luid.value,
                    closure: { [weak self] _, device in
                        if let tag = device.ruuvi?.tag {
                            self?.handleMeasurementPoint(
                                tag: tag,
                                source: .heartbeat
                            )
                        }
                    }
                ))
            }
        }
    }

    private func handleMeasurementPoint(
        tag: RuuviTag,
        source: RuuviTagSensorRecordSource
    ) {
        guard let viewModel = viewModels.first(
            where: { $0.luid.value == tag.uuid.luid.any }
        )
        else {
            return
        }
        let sensorSettings = sensorSettings
            .first(where: {
                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid.value)
                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac.value)
            })
        let record = tag
            .with(source: source)
            .with(sensorSettings: sensorSettings)
        viewModel.update(
            record
        )
        notifyUpdate(for: viewModel)
        alertHandler.process(record: record, trigger: false)
    }

    private func updateSensorSettings(
        _ updatedSensorSettings: SensorSettings,
        _ ruuviTagSensor: AnyRuuviTagSensor
    ) {
        if let updateIndex = sensorSettings.firstIndex(
            where: { $0.id == updatedSensorSettings.id }
        ) {
            sensorSettings[updateIndex] = updatedSensorSettings
            if let viewModel = viewModels.first(where: {
                $0.id.value == ruuviTagSensor.id
            }) {
                notifySensorSettingsUpdate(
                    sensorSettings: updatedSensorSettings,
                    viewModel: viewModel
                )
            }
        } else {
            sensorSettings.append(updatedSensorSettings)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func observeSensorSettings() {
        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        for viewModel in viewModels {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
                sensorSettingsTokens.append(
                    ruuviReactor.observe(ruuviTagSensor) { [weak self] change in
                        guard let sSelf = self else { return }
                        switch change {
                        case let .insert(sensorSettings):
                            self?.sensorSettings.append(sensorSettings)
                            if let viewModel = sSelf.viewModels.first(where: {
                                $0.id.value == ruuviTagSensor.id
                            }) {
                                self?.notifySensorSettingsUpdate(
                                    sensorSettings: sensorSettings,
                                    viewModel: viewModel
                                )
                            }
                        case let .update(updateSensorSettings):
                            self?.updateSensorSettings(updateSensorSettings, ruuviTagSensor)
                        case let .delete(deleteSensorSettings):
                            if let deleteIndex = self?.sensorSettings.firstIndex(
                                where: { $0.id == deleteSensorSettings.id }
                            ) {
                                self?.sensorSettings.remove(at: deleteIndex)
                            }
                            if let viewModel = sSelf.viewModels.first(where: {
                                $0.id.value == ruuviTagSensor.id
                            }) {
                                self?.notifySensorSettingsUpdate(
                                    sensorSettings: deleteSensorSettings,
                                    viewModel: viewModel
                                )
                            }
                        case let .initial(initialSensorSettings):
                            initialSensorSettings.forEach {
                                self?.updateSensorSettings($0, ruuviTagSensor)
                            }
                        case let .error(error):
                            self?.errorPresenter.present(error: error)
                        }
                    }
                )
            }
        }
    }

    private func notifySensorSettingsUpdate(
        sensorSettings: SensorSettings?, viewModel: CardsViewModel
    ) {
        let currentRecord = viewModel.latestMeasurement.value
        let updatedRecord = currentRecord?.with(sensorSettings: sensorSettings)
        guard let updatedRecord
        else {
            return
        }
        viewModel.update(updatedRecord)
        notifyUpdate(for: viewModel)
    }

    private func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { observer, state in
            if state != .poweredOn || !self.isBluetoothPermissionGranted {
                observer.view?.showBluetoothDisabled(
                    userDeclined: !self.isBluetoothPermissionGranted)
            }
        })
    }

    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }

    private func startObservingBackgroundChanges() {
        backgroundToken?.invalidate()
        backgroundToken = NotificationCenter
            .default
            .addObserver(
                forName: .BackgroundPersistenceDidChangeBackground,
                object: nil,
                queue: .main
            ) { [weak self] notification in

                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo {
                    let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier

                    let viewModel = sSelf.view?.viewModels
                        .first(where: { $0.luid.value != nil && $0.luid.value == luid?.any })
                        ?? sSelf.view?.viewModels
                        .first(where: { $0.mac.value != nil && $0.mac.value == macId?.any })
                    if let viewModel {
                        let ruuviTag = sSelf.ruuviTags
                            .first(where: { $0.luid != nil && $0.luid?.any == luid?.any })
                            ?? sSelf.ruuviTags
                            .first(where: { $0.macId != nil && $0.macId?.any == macId?.any })
                        if let ruuviTag {
                            sSelf.ruuviSensorPropertiesService.getImage(for: ruuviTag)
                                .on(success: { image in
                                    viewModel.background.value = image
                                    self?.view?.changeCardBackground(of: viewModel, to: image)
                                }, failure: { [weak self] error in
                                    self?.errorPresenter.present(error: error)
                                })
                        }
                    }
                }
            }
    }

    // swiftlint:disable:next function_body_length
    func startObservingDaemonsErrors() {
        ruuviTagAdvertisementDaemonFailureToken?.invalidate()
        ruuviTagAdvertisementDaemonFailureToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagAdvertisementDaemonDidFail,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let error = userInfo[RuuviTagAdvertisementDaemonDidFailKey.error] as? RUError {
                        self?.errorPresenter.present(error: error)
                    }
                }
            )
        ruuviTagPropertiesDaemonFailureToken?.invalidate()
        ruuviTagPropertiesDaemonFailureToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagPropertiesDaemonDidFail,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let error = userInfo[RuuviTagPropertiesDaemonDidFailKey.error] as? RUError {
                        self?.errorPresenter.present(error: error)
                    }
                }
            )
        ruuviTagHeartbeatDaemonFailureToken?.invalidate()
        ruuviTagHeartbeatDaemonFailureToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagHeartbeatDaemonDidFail,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let error = userInfo[RuuviTagHeartbeatDaemonDidFailKey.error] as? RUError {
                        self?.errorPresenter.present(error: error)
                    }
                }
            )
        ruuviTagReadLogsOperationFailureToken?.invalidate()
        ruuviTagReadLogsOperationFailureToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagReadLogsOperationDidFail,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let error = userInfo[RuuviTagReadLogsOperationDidFailKey.error] as? RUError {
                        self?.errorPresenter.present(error: error)
                    }
                }
            )
    }

    func startObservingDidConnectDisconnectNotifications() {
        didConnectToken?.invalidate()
        didConnectToken = NotificationCenter
            .default
            .addObserver(
                forName: .BTBackgroundDidConnect,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                       let viewModel = self?.viewModels.first(where: { $0.luid.value == uuid.luid.any }) {
                        viewModel.isConnected.value = true
                        self?.notifyUpdate(for: viewModel)
                    }
                }
            )
        didDisconnectToken?.invalidate()
        didDisconnectToken = NotificationCenter
            .default
            .addObserver(
                forName: .BTBackgroundDidDisconnect,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                       let viewModel = self?.viewModels.first(where: { $0.luid.value == uuid.luid.any }) {
                        viewModel.isConnected.value = false
                        self?.notifyUpdate(for: viewModel)
                    }
                }
            )
    }

    private func startObservingCloudModeNotification() {
        cloudModeToken?.invalidate()
        cloudModeToken = NotificationCenter
            .default
            .addObserver(
                forName: .CloudModeDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.handleCloudModeState()
                }
            )
    }

    private func startObservingSensorOrderChanges() {
        sensorOrderChangeToken?.invalidate()
        sensorOrderChangeToken = nil
        sensorOrderChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .DashboardSensorOrderDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.viewModels = self.reorder(self.viewModels)
                        if let viewModel = self.currentVisibleViewModel {
                            if let index = self.viewModels.firstIndex(where: {
                                ($0.luid.value != nil && $0.luid.value == viewModel.luid.value) ||
                                    ($0.mac.value != nil && $0.mac.value == viewModel.mac.value)
                            }) {
                                self.visibleViewModelIndex = index
                            }
                        }
                        self.view?.scroll(to: self.visibleViewModelIndex)
                    }
                }
            )
    }

    /// The method handles all the operations when cloud mode toggle is turned on/off
    private func handleCloudModeState() {
        // Sync with cloud if cloud mode is turned on
        if settings.cloudModeEnabled {
            for viewModel in viewModels where viewModel.isCloud.value ?? false {
                viewModel.isConnected.value = false
                notifyUpdate(for: viewModel)
            }
        }
    }

    // ACTIONS
    private func syncViewModels() {
        let ruuviViewModels = ruuviTags.compactMap { ruuviTag -> CardsViewModel in
            let viewModel = CardsViewModel(ruuviTag)
            ruuviSensorPropertiesService.getImage(for: ruuviTag)
                .on(success: { [weak self] image in
                    viewModel.background.value = image
                    self?.view?.changeCardBackground(of: viewModel, to: image)
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            if let luid = ruuviTag.luid {
                viewModel.isConnected.value = background.isConnected(uuid: luid.value)
            } else if let macId = ruuviTag.macId {
                viewModel.networkSyncStatus.value = localSyncState.getSyncStatus(for: macId)
                viewModel.isConnected.value = false
            } else {
                assertionFailure()
            }
            viewModel.alertState.value = alertService
                .hasRegistrations(for: ruuviTag) ? .registered : .empty
            viewModel.rhAlertLowerBound.value = alertService
                .lowerRelativeHumidity(for: ruuviTag)
            viewModel.rhAlertUpperBound.value = alertService
                .upperRelativeHumidity(for: ruuviTag)
            syncAlerts(ruuviTag: ruuviTag, viewModel: viewModel)
            let op = ruuviStorage.readLatest(ruuviTag)
            op.on { [weak self] record in
                if let record {
                    viewModel.update(record)
                    self?.notifyUpdate(for: viewModel)
                    self?.processAlert(record: record, viewModel: viewModel)
                }
            }

            return viewModel
        }

        viewModels = reorder(ruuviViewModels)

        guard viewModels.count > 0
        else {
            output?.cardsViewDidDismiss(module: self)
            return
        }
    }

    private func reorder(_ viewModels: [CardsViewModel]) -> [CardsViewModel] {
        let sortedSensors: [String] = settings.dashboardSensorOrder
        let sortedAndUniqueArray = viewModels.reduce(
            into: [CardsViewModel]()
        ) { result, element in
            if !result.contains(element) {
                result.append(element)
            }
        }

        if !sortedSensors.isEmpty {
            return sortedAndUniqueArray.sorted { (first, second) -> Bool in
                guard let firstMacId = first.mac.value?.value,
                      let secondMacId = second.mac.value?.value else { return false }
                let firstIndex = sortedSensors.firstIndex(of: firstMacId) ?? Int.max
                let secondIndex = sortedSensors.firstIndex(of: secondMacId) ?? Int.max
                return firstIndex < secondIndex
            }
        } else {
            return sortedAndUniqueArray.sorted { (first, second) -> Bool in
                let firstName = first.name.value?.lowercased() ?? ""
                let secondName = second.name.value?.lowercased() ?? ""
                return firstName < secondName
            }
        }
    }

    private func openTagSettingsScreens(viewModel: CardsViewModel) {
        let sensorSettings = sensorSettings
            .first(where: {
                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid.value)
                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac.value)
            })
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
            router.openTagSettings(
                ruuviTag: ruuviTag,
                latestMeasurement: viewModel.latestMeasurement.value,
                sensorSettings: sensorSettings,
                output: self
            )
        }
    }

    private func showTagCharts(for viewModel: CardsViewModel?) {
        guard let viewModel else { return }
        viewDidTriggerShowChart(for: viewModel)
    }

    private func processAlert(
        record: RuuviTagSensorRecord,
        viewModel: CardsViewModel
    ) {
        if let isCloud = viewModel.isCloud.value, isCloud,
           let macId = viewModel.mac.value {
            alertHandler.processNetwork(
                record: record,
                trigger: false,
                for: macId
            )
        } else {
            if viewModel.luid.value != nil {
                alertHandler.process(record: record, trigger: false)
            } else {
                guard let macId = viewModel.mac.value
                else {
                    return
                }
                alertHandler.processNetwork(record: record, trigger: false, for: macId)
            }
        }
    }

    private func notifyUpdate(for viewModel: CardsViewModel) {
        view?.applyUpdate(to: viewModel)
    }

    private func shutdownModule() {
        ruuviTagToken?.invalidate()
        ruuviTagObserveLastRecordTokens.forEach { $0.invalidate() }
        advertisementTokens.forEach { $0.invalidate() }
        heartbeatTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.forEach { $0.invalidate() }
        stateToken?.invalidate()
        backgroundToken?.invalidate()
        alertDidChangeToken?.invalidate()
        ruuviTagAdvertisementDaemonFailureToken?.invalidate()
        ruuviTagPropertiesDaemonFailureToken?.invalidate()
        ruuviTagHeartbeatDaemonFailureToken?.invalidate()
        ruuviTagReadLogsOperationFailureToken?.invalidate()
        startKeepingConnectionToken?.invalidate()
        stopKeepingConnectionToken?.invalidate()
        readRSSIToken?.invalidate()
        readRSSIIntervalToken?.invalidate()
        didConnectToken?.invalidate()
        didDisconnectToken?.invalidate()
        cloudModeToken?.invalidate()
        mutedTillTimer?.invalidate()
        sensorOrderChangeToken?.invalidate()
        router.dismiss()
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
}

// MARK: - CardsViewOutput

extension CardsPresenter: CardsViewOutput {
    func viewDidLoad() {
        startObservingAppState()
        startMutedTillTimer()
        startObservingSensorOrderChanges()
    }

    func viewWillAppear() {
        guard viewModels.count > 0
        else {
            return
        }
        view?.scroll(to: visibleViewModelIndex)
        startObservingBluetoothState()
    }

    func viewDidAppear() {
        // No op.
    }

    func viewWillDisappear() {
        stopObservingBluetoothState()
    }

    func viewDidTriggerSettings(for viewModel: CardsViewModel) {
        if viewModel.type == .ruuvi {
            if let luid = viewModel.luid.value {
                if settings.keepConnectionDialogWasShown(for: luid)
                    || background.isConnected(uuid: luid.value)
                    || !viewModel.isConnectable.value.bound
                    || !viewModel.isOwner.value.bound
                    || (settings.cloudModeEnabled && viewModel.isCloud.value.bound) {
                    openTagSettingsScreens(viewModel: viewModel)
                } else {
                    view?.showKeepConnectionDialogSettings(for: viewModel)
                }
            } else {
                openTagSettingsScreens(viewModel: viewModel)
            }
        }
    }

    func viewDidTriggerShowChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            if settings.keepConnectionDialogWasShown(for: luid)
                || background.isConnected(uuid: luid.value)
                || !viewModel.isConnectable.value.bound
                || !viewModel.isOwner.value.bound
                || (settings.cloudModeEnabled && viewModel.isCloud.value.bound) {
                if let sensor = ruuviTags
                    .first(where: {
                        $0.macId != nil && ($0.macId?.any == viewModel.mac.value)
                    }) {
                    showCharts(for: sensor)
                }
            } else {
                view?.showKeepConnectionDialogChart(for: viewModel)
            }
        } else if viewModel.mac.value != nil {
            if let sensor = ruuviTags
                .first(where: {
                    $0.macId != nil && ($0.macId?.any == viewModel.mac.value)
                }) {
                showCharts(for: sensor)
            }
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerNavigateChart(to viewModel: CardsViewModel) {
        if let tagCharts, let sensor = ruuviTags
            .first(where: {
                $0.macId != nil && ($0.macId?.any == viewModel.mac.value)
            }) {
            tagCharts.scrollTo(ruuviTag: sensor)
        }
    }

    func viewDidTriggerDismissChart(
        for _: CardsViewModel,
        dismissParent: Bool
    ) {
        tagCharts?.notifyDismissInstruction(dismissParent: dismissParent)
    }

    private func showCharts(for sensor: AnyRuuviTagSensor) {
        let factory: TagChartsModuleFactory = TagChartsModuleFactoryImpl()
        let module = factory.create()
        tagChartsModule = module
        if let tagChartsPresenter = module.output as? TagChartsViewModuleInput {
            tagCharts = tagChartsPresenter
            tagCharts?.configure(output: self)
            tagCharts?.configure(ruuviTag: sensor)
        }
        view?.showChart(module: module)
    }

    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            settings.setKeepConnectionDialogWasShown(for: luid)
            if let sensor = ruuviTags
                .first(where: {
                    $0.macId != nil && ($0.macId?.any == viewModel.mac.value)
                }) {
                showCharts(for: sensor)
            }
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            if let sensor = ruuviTags
                .first(where: {
                    $0.macId != nil && ($0.macId?.any == viewModel.mac.value)
                }) {
                showCharts(for: sensor)
            }
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        guard let luid = viewModel.luid.value,
              let version = viewModel.version.value, version < 5,
              viewModel.isOwner.value.bound,
              featureToggleService.isEnabled(.legacyFirmwareUpdatePopup)
        else {
            return
        }
        if !settings.firmwareUpdateDialogWasShown(for: luid) {
            view?.showFirmwareUpdateDialog(for: viewModel)
        }
    }

    func viewDidConfirmFirmwareUpdate(for viewModel: CardsViewModel) {
        if let sensor = ruuviTags
            .first(where: {
                $0.luid != nil && ($0.luid?.any == viewModel.luid.value)
            }) {
            router.openUpdateFirmware(ruuviTag: sensor)
        }
    }

    func viewDidIgnoreFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        view?.showFirmwareDismissConfirmationUpdateDialog(for: viewModel)
    }

    func viewDidDismissFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        guard let luid = viewModel.luid.value else { return }
        settings.setFirmwareUpdateDialogWasShown(for: luid)
    }

    func viewDidScroll(to viewModel: CardsViewModel) {
        if let sensor = ruuviTags
            .first(where: {
                ($0.luid != nil && ($0.luid?.any == viewModel.luid.value))
                    || ($0.macId != nil && ($0.macId?.any == viewModel.mac.value))
            }) {
            updateVisibleCard(from: viewModel)
            checkFirmwareVersion(for: sensor)
        }
    }

    func viewShouldDismiss() {
        view?.dismissChart()
        output?.cardsViewDidDismiss(module: self)
    }
}

// MARK: - TagChartsModuleOutput

extension CardsPresenter: TagChartsViewModuleOutput {
    func tagChartSafeToClose(
        module: TagChartsViewModuleInput,
        dismissParent: Bool
    ) {
        module.dismiss(completion: { [weak self] in
            if dismissParent {
                self?.viewShouldDismiss()
            } else {
                self?.view?.dismissChart()
            }
        })
    }

    func tagChartSafeToSwipe(
        to ruuviTag: AnyRuuviTagSensor, module _: TagChartsViewModuleInput
    ) {
        if let viewModel = viewModels.first(where: {
            ($0.luid.value != nil && $0.luid.value == ruuviTag.luid?.any)
                || ($0.mac.value != nil && $0.mac.value == ruuviTag.macId?.any)
        }) {
            updateVisibleCard(
                from: viewModel,
                triggerScroll: true
            )
            view?.scroll(to: visibleViewModelIndex)
        }
    }
}

// MARK: - RuuviNotifierObserver

extension CardsPresenter: RuuviNotifierObserver {
    func ruuvi(notifier _: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        viewModels
            .filter { $0.luid.value?.value == uuid || $0.mac.value?.value == uuid }
            .forEach { viewModel in
                let newValue: AlertState = isTriggered ? .firing : .registered
                viewModel.alertState.value = newValue
                notifyUpdate(for: viewModel)
            }
    }
}

// MARK: - TagSettingsModuleOutput

extension CardsPresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(
        module: TagSettingsModuleInput,
        ruuviTag: RuuviTagSensor
    ) {
        module.dismiss(completion: { [weak self] in
            guard let self else { return }
            view?.dismissChart()
            output?.cardsViewDidRefresh(module: self)
            if let index = viewModels.firstIndex(where: {
                ($0.luid.value != nil && $0.luid.value == ruuviTag.luid?.any) ||
                    ($0.mac.value != nil && $0.mac.value == ruuviTag.macId?.any)
            }) {
                viewModels.remove(at: index)
                view?.viewModels = viewModels
            }

            if viewModels.count > 0,
               let first = viewModels.first {
                updateVisibleCard(from: first, triggerScroll: true)
            } else {
                viewShouldDismiss()
            }
        })
    }

    func tagSettingsDidDismiss(module: TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}

// MARK: - Private

extension CardsPresenter {
    private func checkFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.interactor.checkAndUpdateFirmwareVersion(
                for: ruuviTag,
                settings: sSelf.settings
            )
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func syncAlerts(ruuviTag: RuuviTagSensor, viewModel: CardsViewModel) {
        AlertType.allCases.forEach { type in
            switch type {
            case .temperature:
                sync(
                    temperature: type,
                    ruuviTag: ruuviTag,
                    viewModel: viewModel
                )
            case .relativeHumidity:
                sync(relativeHumidity: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pressure:
                sync(pressure: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .signal:
                sync(signal: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .carbonDioxide:
                sync(carbonDioxide: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pMatter1:
                sync(pMatter1: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pMatter2_5:
                sync(pMatter2_5: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pMatter4:
                sync(pMatter4: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pMatter10:
                sync(pMatter10: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .voc:
                sync(voc: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .nox:
                sync(nox: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .sound:
                sync(sound: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .luminosity:
                sync(luminosity: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .connection:
                sync(connection: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .movement:
                sync(movement: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .cloudConnection:
                sync(cloudConnection: type, ruuviTag: ruuviTag, viewModel: viewModel)
            default: break
            }
        }

        let alertStates = [
            viewModel.temperatureAlertState.value,
            viewModel.relativeHumidityAlertState.value,
            viewModel.pressureAlertState.value,
            viewModel.signalAlertState.value,
            viewModel.carbonDioxideAlertState.value,
            viewModel.pMatter1AlertState.value,
            viewModel.pMatter2_5AlertState.value,
            viewModel.pMatter4AlertState.value,
            viewModel.pMatter10AlertState.value,
            viewModel.vocAlertState.value,
            viewModel.noxAlertState.value,
            viewModel.soundAlertState.value,
            viewModel.luminosityAlertState.value,
            viewModel.connectionAlertState.value,
            viewModel.movementAlertState.value,
            viewModel.cloudConnectionAlertState.value,
        ]

        if alertService.hasRegistrations(for: ruuviTag) {
            if alertStates.first(where: { alert in
                alert == .firing
            }) != nil {
                viewModel.alertState.value = .firing
            } else {
                viewModel.alertState.value = .registered
            }
        } else {
            viewModel.alertState.value = .empty
        }

        notifyUpdate(for: viewModel)
    }

    private func sync(
        temperature: AlertType,
        ruuviTag: RuuviTagSensor,
        viewModel: CardsViewModel
    ) {
        if case .temperature = alertService.alert(
            for: ruuviTag,
            of: temperature
        ) {
            viewModel.isTemperatureAlertOn.value = true
        } else {
            viewModel.isTemperatureAlertOn.value = false
        }
        viewModel.temperatureAlertMutedTill.value = alertService.mutedTill(type: temperature, for: ruuviTag)
    }

    private func sync(
        relativeHumidity: AlertType,
        ruuviTag: RuuviTagSensor,
        viewModel: CardsViewModel
    ) {
        if case .relativeHumidity = alertService.alert(
            for: ruuviTag,
            of: relativeHumidity
        ) {
            viewModel.isRelativeHumidityAlertOn.value = true
        } else {
            viewModel.isRelativeHumidityAlertOn.value = false
        }
        viewModel.relativeHumidityAlertMutedTill.value = alertService
            .mutedTill(
                type: relativeHumidity,
                for: ruuviTag
            )
    }

    private func sync(
        pressure: AlertType,
        ruuviTag: RuuviTagSensor,
        viewModel: CardsViewModel
    ) {
        if case .pressure = alertService.alert(
            for: ruuviTag,
            of: pressure
        ) {
            viewModel.isPressureAlertOn.value = true
        } else {
            viewModel.isPressureAlertOn.value = false
        }
        viewModel.pressureAlertMutedTill.value = alertService
            .mutedTill(
                type: pressure,
                for: ruuviTag
            )
    }

    private func sync(
        signal: AlertType,
        ruuviTag: RuuviTagSensor,
        viewModel: CardsViewModel
    ) {
        if case .signal = alertService.alert(
            for: ruuviTag,
            of: signal
        ) {
            viewModel.isSignalAlertOn.value = true
        } else {
            viewModel.isSignalAlertOn.value = false
        }
        viewModel.signalAlertMutedTill.value =
            alertService.mutedTill(
                type: signal,
                for: ruuviTag
            )
    }

    private func sync(
        carbonDioxide: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .carbonDioxide = alertService
            .alert(for: ruuviTag, of: carbonDioxide) {
            viewModel.isCarbonDioxideAlertOn.value = true
        } else {
            viewModel.isCarbonDioxideAlertOn.value = false
        }
        viewModel.carbonDioxideAlertMutedTill.value =
            alertService.mutedTill(
                type: carbonDioxide,
                for: ruuviTag
            )
    }

    private func sync(
        pMatter1: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter1 = alertService
            .alert(for: ruuviTag, of: pMatter1) {
            viewModel.isPMatter1AlertOn.value = true
        } else {
            viewModel.isPMatter1AlertOn.value = false
        }
        viewModel.pMatter1AlertMutedTill.value =
            alertService.mutedTill(
                type: pMatter1,
                for: ruuviTag
            )
    }

    private func sync(
        pMatter2_5: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter2_5 = alertService
            .alert(for: ruuviTag, of: pMatter2_5) {
            viewModel.isPMatter2_5AlertOn.value = true
        } else {
            viewModel.isPMatter2_5AlertOn.value = false
        }
        viewModel.pMatter2_5AlertMutedTill.value =
            alertService.mutedTill(
                type: pMatter2_5,
                for: ruuviTag
            )
    }

    private func sync(
        pMatter4: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter4 = alertService
            .alert(for: ruuviTag, of: pMatter4) {
            viewModel.isPMatter4AlertOn.value = true
        } else {
            viewModel.isPMatter4AlertOn.value = false
        }
        viewModel.pMatter4AlertMutedTill.value =
            alertService.mutedTill(
                type: pMatter4,
                for: ruuviTag
            )
    }

    private func sync(
        pMatter10: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter10 = alertService
            .alert(for: ruuviTag, of: pMatter10) {
            viewModel.isPMatter10AlertOn.value = true
        } else {
            viewModel.isPMatter10AlertOn.value = false
        }
        viewModel.pMatter10AlertMutedTill.value =
            alertService.mutedTill(
                type: pMatter10,
                for: ruuviTag
            )
    }

    private func sync(
        voc: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .voc = alertService.alert(for: ruuviTag, of: voc) {
            viewModel.isVOCAlertOn.value = true
        } else {
            viewModel.isVOCAlertOn.value = false
        }
        viewModel.vocAlertMutedTill.value =
            alertService.mutedTill(
                type: voc,
                for: ruuviTag
            )
    }

    private func sync(
        nox: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .nox = alertService.alert(for: ruuviTag, of: nox) {
            viewModel.isNOXAlertOn.value = true
        } else {
            viewModel.isNOXAlertOn.value = false
        }
        viewModel.noxAlertMutedTill.value =
            alertService.mutedTill(
                type: nox,
                for: ruuviTag
            )
    }

    private func sync(
        sound: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .sound = alertService.alert(for: ruuviTag, of: sound) {
            viewModel.isSignalAlertOn.value = true
        } else {
            viewModel.isSoundAlertOn.value = false
        }
        viewModel.soundAlertMutedTill.value =
            alertService.mutedTill(
                type: sound,
                for: ruuviTag
            )
    }

    private func sync(
        luminosity: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .luminosity = alertService.alert(for: ruuviTag, of: luminosity) {
            viewModel.isLuminosityAlertOn.value = true
        } else {
            viewModel.isLuminosityAlertOn.value = false
        }
        viewModel.luminosityAlertMutedTill.value =
            alertService.mutedTill(
                type: luminosity,
                for: ruuviTag
            )
    }

    private func sync(
        connection: AlertType,
        ruuviTag: RuuviTagSensor,
        viewModel: CardsViewModel
    ) {
        if case .connection = alertService.alert(for: ruuviTag, of: connection) {
            viewModel.isConnectionAlertOn.value = true
        } else {
            viewModel.isConnectionAlertOn.value = false
        }
        viewModel.connectionAlertMutedTill.value = alertService
            .mutedTill(
                type: connection,
                for: ruuviTag
            )
    }

    private func sync(
        movement: AlertType,
        ruuviTag: RuuviTagSensor,
        viewModel: CardsViewModel
    ) {
        if case .movement = alertService.alert(for: ruuviTag, of: movement) {
            viewModel.isMovementAlertOn.value = true
        } else {
            viewModel.isMovementAlertOn.value = false
        }
        viewModel.movementAlertMutedTill.value = alertService
            .mutedTill(
                type: movement,
                for: ruuviTag
            )
    }

    private func sync(
        cloudConnection: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .cloudConnection = alertService.alert(for: ruuviTag, of: cloudConnection) {
            viewModel.isCloudConnectionAlertOn.value = true
        } else {
            viewModel.isCloudConnectionAlertOn.value = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func reloadMutedTill() {
        for viewModel in viewModels {
            if let mutedTill = viewModel.temperatureAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.temperatureAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.relativeHumidityAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.relativeHumidityAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.pressureAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.pressureAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.signalAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.signalAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.carbonDioxideAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.carbonDioxideAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.pMatter1AlertMutedTill.value,
               mutedTill < Date() {
                viewModel.pMatter1AlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.pMatter2_5AlertMutedTill.value,
               mutedTill < Date() {
                viewModel.pMatter2_5AlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.pMatter4AlertMutedTill.value,
               mutedTill < Date() {
                viewModel.pMatter4AlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.pMatter10AlertMutedTill.value,
               mutedTill < Date() {
                viewModel.pMatter10AlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.vocAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.vocAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.noxAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.noxAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.soundAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.soundAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.luminosityAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.luminosityAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.connectionAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.connectionAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.movementAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.movementAlertMutedTill.value = nil
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func updateMutedTill(
        of type: AlertType,
        for uuid: String,
        viewModel: CardsViewModel
    ) {
        let observable: Observable<Date?> = switch type {
        case .temperature:
            viewModel.temperatureAlertMutedTill
        case .relativeHumidity:
            viewModel.relativeHumidityAlertMutedTill
        case .pressure:
            viewModel.pressureAlertMutedTill
        case .signal:
            viewModel.signalAlertMutedTill
        case .carbonDioxide:
            viewModel.carbonDioxideAlertMutedTill
        case .pMatter1:
            viewModel.pMatter1AlertMutedTill
        case .pMatter2_5:
            viewModel.pMatter2_5AlertMutedTill
        case .pMatter4:
            viewModel.pMatter4AlertMutedTill
        case .pMatter10:
            viewModel.pMatter10AlertMutedTill
        case .voc:
            viewModel.vocAlertMutedTill
        case .nox:
            viewModel.noxAlertMutedTill
        case .sound:
            viewModel.soundAlertMutedTill
        case .luminosity:
            viewModel.luminosityAlertMutedTill
        case .connection:
            viewModel.connectionAlertMutedTill
        case .movement:
            viewModel.movementAlertMutedTill
        default:
            // Should never be here
            viewModel.temperatureAlertMutedTill
        }

        let date = alertService.mutedTill(type: type, for: uuid)
        if date != observable.value {
            observable.value = date
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func updateIsOnState(
        of type: AlertType,
        for uuid: String,
        viewModel: CardsViewModel
    ) {
        let observable: Observable<Bool?> = switch type {
        case .temperature:
            viewModel.isTemperatureAlertOn
        case .relativeHumidity:
            viewModel.isRelativeHumidityAlertOn
        case .pressure:
            viewModel.isPressureAlertOn
        case .signal:
            viewModel.isSignalAlertOn
        case .carbonDioxide:
            viewModel.isCarbonDioxideAlertOn
        case .pMatter1:
            viewModel.isPMatter1AlertOn
        case .pMatter2_5:
            viewModel.isPMatter2_5AlertOn
        case .pMatter4:
            viewModel.isPMatter4AlertOn
        case .pMatter10:
            viewModel.isPMatter10AlertOn
        case .voc:
            viewModel.isVOCAlertOn
        case .nox:
            viewModel.isNOXAlertOn
        case .sound:
            viewModel.isSoundAlertOn
        case .luminosity:
            viewModel.isLuminosityAlertOn
        case .connection:
            viewModel.isConnectionAlertOn
        case .movement:
            viewModel.isMovementAlertOn
        case .cloudConnection:
            viewModel.isCloudConnectionAlertOn
        default:
            // Should never be here
            viewModel.isTemperatureAlertOn
        }

        let isOn = alertService.isOn(type: type, for: uuid)
        if isOn != observable.value {
            observable.value = isOn
        }
    }

    private func notifyRestartAdvertisementDaemon() {
        // Notify daemon to restart
        NotificationCenter
            .default
            .post(
                name: .RuuviTagAdvertisementDaemonShouldRestart,
                object: nil,
                userInfo: nil
            )
    }

    private func notifyRestartHeartBeatDaemon() {
        // Notify daemon to restart
        NotificationCenter
            .default
            .post(
                name: .RuuviTagHeartBeatDaemonShouldRestart,
                object: nil,
                userInfo: nil
            )
    }
}

// swiftlint:enable file_length
