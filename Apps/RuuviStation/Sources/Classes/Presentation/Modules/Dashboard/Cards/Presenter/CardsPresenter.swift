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

    // MARK: - CardsViewOutput
    var showingChart: Bool = false

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
    private var sensorSettingsTokens = [RuuviReactorToken]()
    private var stateToken: ObservationToken?
    private var backgroundToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var ruuviTagAdvertisementDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagPropertiesDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagHeartbeatDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagReadLogsOperationFailureToken: NSObjectProtocol?
    private var readRSSIToken: NSObjectProtocol?
    private var readRSSIIntervalToken: NSObjectProtocol?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var cloudModeToken: NSObjectProtocol?
    private var sensorOrderChangeToken: NSObjectProtocol?
    private var latestDataSyncToken: NSObjectProtocol?
    private var historySyncToken: NSObjectProtocol?

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
        startListeningLatestRecords()
        startListeningToRuuviTagsAlertStatus()
        startObservingAlertChanges()
        startObservingBackgroundChanges()
        startObservingDaemonsErrors()
        startObservingDidConnectDisconnectNotifications()
        startObservingCloudModeNotification()
        startObservingCloudLatestDataSyncNotification()
        startObservingCloudHistorySyncNotification()
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
            ($0.luid != nil && $0.luid == viewModel?.luid) ||
                ($0.mac != nil && $0.mac == viewModel?.mac)
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
                    ($0.luid != nil && $0.luid == sensor.luid?.any)
                        || ($0.mac != nil && $0.mac == sensor.macId?.any)
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
                    sSelf.view?.scroll(to: sSelf.visibleViewModelIndex)
                }

            case let .delete(sensor):
                sSelf.notifyRestartAdvertisementDaemon()
                sSelf.notifyRestartHeartBeatDaemon()
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
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id }) {
                let token = ruuviReactor.observeLatest(ruuviTagSensor) { [weak self] changes in
                    if case let .update(anyRecord) = changes,
                       let viewModel = self?.viewModels
                           .first(where: {
                               ($0.luid != nil && ($0.luid == anyRecord?.luid?.any))
                                   || ($0.mac != nil && ($0.mac == anyRecord?.macId?.any))
                           }),
                           let record = anyRecord {
                        let sensorSettings = self?.sensorSettings
                            .first(where: {
                                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
                                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
                            })
                        let sensorRecord = record.with(sensorSettings: sensorSettings)
                        viewModel.update(sensorRecord)
                        self?.notifyUpdate(for: viewModel)

                        DispatchQueue.global(qos: .utility).async {
                            self?.processAlert(record: sensorRecord, viewModel: viewModel)
                        }
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
                                ($0.luid != nil && ($0.luid == physicalSensor.luid?.any))
                                    || ($0.mac != nil && ($0.mac == physicalSensor.macId?.any))
                            }.forEach { viewModel in
                                if sSelf.alertService.hasRegistrations(for: physicalSensor) {
                                    viewModel.alertState = .registered
                                } else {
                                    viewModel.alertState = .empty
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

    private func handleMeasurementPoint(
        tag: RuuviTag,
        source: RuuviTagSensorRecordSource
    ) {
        guard let viewModel = viewModels.first(
            where: { $0.luid == tag.uuid.luid.any }
        )
        else {
            return
        }
        let sensorSettings = sensorSettings
            .first(where: {
                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
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
                $0.id == ruuviTagSensor.id
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
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id }) {
                sensorSettingsTokens.append(
                    ruuviReactor.observe(ruuviTagSensor) { [weak self] change in
                        guard let sSelf = self else { return }
                        switch change {
                        case let .insert(sensorSettings):
                            self?.sensorSettings.append(sensorSettings)
                            if let viewModel = sSelf.viewModels.first(where: {
                                $0.id == ruuviTagSensor.id
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
                                $0.id == ruuviTagSensor.id
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
        let currentRecord = viewModel.latestMeasurement
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
                        .first(where: { $0.luid != nil && $0.luid == luid?.any })
                        ?? sSelf.view?.viewModels
                        .first(where: { $0.mac != nil && $0.mac == macId?.any })
                    if let viewModel {
                        let ruuviTag = sSelf.ruuviTags
                            .first(where: { $0.luid != nil && $0.luid?.any == luid?.any })
                            ?? sSelf.ruuviTags
                            .first(where: { $0.macId != nil && $0.macId?.any == macId?.any })
                        if let ruuviTag {
                            sSelf.ruuviSensorPropertiesService.getImage(for: ruuviTag)
                                .on(success: { image in
                                    viewModel.background = image
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
                       let viewModel = self?.viewModels.first(where: { $0.luid == uuid.luid.any }) {
                        viewModel.isConnected = true
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
                       let viewModel = self?.viewModels.first(where: { $0.luid == uuid.luid.any }) {
                        viewModel.isConnected = false
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
                                ($0.luid != nil && $0.luid == viewModel.luid) ||
                                    ($0.mac != nil && $0.mac == viewModel.mac)
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
            for viewModel in viewModels where viewModel.isCloud {
                viewModel.isConnected = false
                notifyUpdate(for: viewModel)
            }
        }
    }

    // ACTIONS
    private func syncViewModels() {
        let ruuviViewModels = ruuviTags.compactMap { ruuviTag -> CardsViewModel in
            let viewModel = CardsViewModel(ruuviTag)
            ruuviSensorPropertiesService.getImage(for: ruuviTag)
                .on(success: { image in
                    viewModel.background = image
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            if let luid = ruuviTag.luid {
                viewModel.isConnected = background.isConnected(uuid: luid.value)
            } else if let macId = ruuviTag.macId {
                viewModel.networkSyncStatus = localSyncState.getSyncStatusLatestRecord(for: macId)
                viewModel.isConnected = false
            } else {
                assertionFailure()
            }
            viewModel.alertState = alertService
                .hasRegistrations(for: ruuviTag) ? .registered : .empty
            viewModel.rhAlertLowerBound = alertService
                .lowerRelativeHumidity(for: ruuviTag)
            viewModel.rhAlertUpperBound = alertService
                .upperRelativeHumidity(for: ruuviTag)
            // Inject previous record if available that will prevent showing nil
            // value while this method is rebuilding the collection and fetching
            // latest record from storage asynchronously.
            if let previousRecord = viewModels.first(where: {
                $0.id == ruuviTag.id
            })?.latestMeasurement {
                viewModel.update(previousRecord)
            }
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
                guard let firstMacId = first.mac?.value,
                      let secondMacId = second.mac?.value else { return false }
                let firstIndex = sortedSensors.firstIndex(of: firstMacId) ?? Int.max
                let secondIndex = sortedSensors.firstIndex(of: secondMacId) ?? Int.max
                return firstIndex < secondIndex
            }
        } else {
            return sortedAndUniqueArray.sorted { (first, second) -> Bool in
                let firstName = first.name.lowercased()
                let secondName = second.name.lowercased()
                return firstName < secondName
            }
        }
    }

    private func openTagSettingsScreens(viewModel: CardsViewModel) {
        let sensorSettings = sensorSettings
            .first(where: {
                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
            })
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id }) {
            router.openTagSettings(
                ruuviTag: ruuviTag,
                latestMeasurement: viewModel.latestMeasurement,
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
        if viewModel.isCloud,
           let macId = viewModel.mac {
            alertHandler.processNetwork(
                record: record,
                trigger: false,
                for: macId
            )
        } else {
            if viewModel.luid != nil {
                alertHandler.process(record: record, trigger: false)
            } else {
                guard let macId = viewModel.mac
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
        sensorSettingsTokens.forEach { $0.invalidate() }
        stateToken?.invalidate()
        backgroundToken?.invalidate()
        alertDidChangeToken?.invalidate()
        ruuviTagAdvertisementDaemonFailureToken?.invalidate()
        ruuviTagPropertiesDaemonFailureToken?.invalidate()
        ruuviTagHeartbeatDaemonFailureToken?.invalidate()
        ruuviTagReadLogsOperationFailureToken?.invalidate()
        readRSSIToken?.invalidate()
        readRSSIIntervalToken?.invalidate()
        didConnectToken?.invalidate()
        didDisconnectToken?.invalidate()
        cloudModeToken?.invalidate()
        mutedTillTimer?.invalidate()
        sensorOrderChangeToken?.invalidate()
        latestDataSyncToken?.invalidate()
        historySyncToken?.invalidate()
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
            if let luid = viewModel.luid {
                if settings.keepConnectionDialogWasShown(for: luid)
                    || background.isConnected(uuid: luid.value)
                    || !viewModel.isConnectable
                    || !viewModel.isOwner
                    || (settings.cloudModeEnabled && viewModel.isCloud) {
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
        if let luid = viewModel.luid {
            if settings.keepConnectionDialogWasShown(for: luid)
                || background.isConnected(uuid: luid.value)
                || !viewModel.isConnectable
                || !viewModel.isOwner
                || (settings.cloudModeEnabled && viewModel.isCloud) {
                if let sensor = ruuviTags
                    .first(where: {
                        $0.macId != nil && ($0.macId?.any == viewModel.mac)
                    }) {
                    showCharts(for: sensor)
                }
            } else {
                view?.showKeepConnectionDialogChart(for: viewModel)
            }
        } else if viewModel.mac != nil {
            if let sensor = ruuviTags
                .first(where: {
                    $0.macId != nil && ($0.macId?.any == viewModel.mac)
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
                $0.macId != nil && ($0.macId?.any == viewModel.mac)
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
            view?.showChart(module: module)
        }
    }

    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            settings.setKeepConnectionDialogWasShown(for: luid)
            if let sensor = ruuviTags
                .first(where: {
                    $0.macId != nil && ($0.macId?.any == viewModel.mac)
                }) {
                showCharts(for: sensor)
            }
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            if let sensor = ruuviTags
                .first(where: {
                    $0.macId != nil && ($0.macId?.any == viewModel.mac)
                }) {
                showCharts(for: sensor)
            }
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        guard let luid = viewModel.luid,
              let version = viewModel.version, version < 5,
              viewModel.isOwner,
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
                $0.luid != nil && ($0.luid?.any == viewModel.luid)
            }) {
            router.openUpdateFirmware(ruuviTag: sensor)
        }
    }

    func viewDidIgnoreFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        view?.showFirmwareDismissConfirmationUpdateDialog(for: viewModel)
    }

    func viewDidDismissFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        guard let luid = viewModel.luid else { return }
        settings.setFirmwareUpdateDialogWasShown(for: luid)
    }

    func viewDidScroll(to viewModel: CardsViewModel) {
        if let sensor = ruuviTags
            .first(where: {
                ($0.luid != nil && ($0.luid?.any == viewModel.luid))
                    || ($0.macId != nil && ($0.macId?.any == viewModel.mac))
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
            ($0.luid != nil && $0.luid == ruuviTag.luid?.any)
                || ($0.mac != nil && $0.mac == ruuviTag.macId?.any)
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
            .filter { $0.luid?.value == uuid || $0.mac?.value == uuid }
            .forEach { viewModel in
                let newValue: AlertState = isTriggered ? .firing : .registered
                if newValue != viewModel.alertState {
                    viewModel.alertState = newValue
                    notifyUpdate(for: viewModel)
                }
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
                ($0.luid != nil && $0.luid == ruuviTag.luid?.any) ||
                    ($0.mac != nil && $0.mac == ruuviTag.macId?.any)
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
            case .pMatter25:
                sync(pMatter25: type, ruuviTag: ruuviTag, viewModel: viewModel)
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
            viewModel.temperatureAlertState,
            viewModel.relativeHumidityAlertState,
            viewModel.pressureAlertState,
            viewModel.signalAlertState,
            viewModel.carbonDioxideAlertState,
            viewModel.pMatter1AlertState,
            viewModel.pMatter25AlertState,
            viewModel.pMatter4AlertState,
            viewModel.pMatter10AlertState,
            viewModel.vocAlertState,
            viewModel.noxAlertState,
            viewModel.soundAlertState,
            viewModel.luminosityAlertState,
            viewModel.connectionAlertState,
            viewModel.movementAlertState,
            viewModel.cloudConnectionAlertState,
        ]

        if alertService.hasRegistrations(for: ruuviTag) {
            if alertStates.first(where: { alert in
                alert == .firing
            }) != nil {
                if viewModel.alertState != .firing {
                    viewModel.alertState = .firing
                    notifyUpdate(for: viewModel)
                }
            } else {
                if viewModel.alertState != .registered {
                    viewModel.alertState = .registered
                    notifyUpdate(for: viewModel)
                }
            }
        } else {
            if viewModel.alertState != .empty {
                viewModel.alertState = .empty
                notifyUpdate(for: viewModel)
            }
        }
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
            viewModel.isTemperatureAlertOn = true
        } else {
            viewModel.isTemperatureAlertOn = false
        }
        viewModel.temperatureAlertMutedTill = alertService.mutedTill(type: temperature, for: ruuviTag)
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
            viewModel.isRelativeHumidityAlertOn = true
        } else {
            viewModel.isRelativeHumidityAlertOn = false
        }
        viewModel.relativeHumidityAlertMutedTill = alertService
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
            viewModel.isPressureAlertOn = true
        } else {
            viewModel.isPressureAlertOn = false
        }
        viewModel.pressureAlertMutedTill = alertService
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
            viewModel.isSignalAlertOn = true
        } else {
            viewModel.isSignalAlertOn = false
        }
        viewModel.signalAlertMutedTill =
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
            viewModel.isCarbonDioxideAlertOn = true
        } else {
            viewModel.isCarbonDioxideAlertOn = false
        }
        viewModel.carbonDioxideAlertMutedTill =
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
            viewModel.isPMatter1AlertOn = true
        } else {
            viewModel.isPMatter1AlertOn = false
        }
        viewModel.pMatter1AlertMutedTill =
            alertService.mutedTill(
                type: pMatter1,
                for: ruuviTag
            )
    }

    private func sync(
        pMatter25: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter25 = alertService
            .alert(for: ruuviTag, of: pMatter25) {
            viewModel.isPMatter25AlertOn = true
        } else {
            viewModel.isPMatter25AlertOn = false
        }
        viewModel.pMatter25AlertMutedTill =
            alertService.mutedTill(
                type: pMatter25,
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
            viewModel.isPMatter4AlertOn = true
        } else {
            viewModel.isPMatter4AlertOn = false
        }
        viewModel.pMatter4AlertMutedTill =
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
            viewModel.isPMatter10AlertOn = true
        } else {
            viewModel.isPMatter10AlertOn = false
        }
        viewModel.pMatter10AlertMutedTill =
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
            viewModel.isVOCAlertOn = true
        } else {
            viewModel.isVOCAlertOn = false
        }
        viewModel.vocAlertMutedTill =
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
            viewModel.isNOXAlertOn = true
        } else {
            viewModel.isNOXAlertOn = false
        }
        viewModel.noxAlertMutedTill =
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
            viewModel.isSignalAlertOn = true
        } else {
            viewModel.isSoundAlertOn = false
        }
        viewModel.soundAlertMutedTill =
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
            viewModel.isLuminosityAlertOn = true
        } else {
            viewModel.isLuminosityAlertOn = false
        }
        viewModel.luminosityAlertMutedTill =
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
            viewModel.isConnectionAlertOn = true
        } else {
            viewModel.isConnectionAlertOn = false
        }
        viewModel.connectionAlertMutedTill = alertService
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
            viewModel.isMovementAlertOn = true
        } else {
            viewModel.isMovementAlertOn = false
        }
        viewModel.movementAlertMutedTill = alertService
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
            viewModel.isCloudConnectionAlertOn = true
        } else {
            viewModel.isCloudConnectionAlertOn = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func reloadMutedTill() {
        for viewModel in viewModels {
            if let mutedTill = viewModel.temperatureAlertMutedTill,
               mutedTill < Date() {
                viewModel.temperatureAlertMutedTill = nil
            }

            if let mutedTill = viewModel.relativeHumidityAlertMutedTill,
               mutedTill < Date() {
                viewModel.relativeHumidityAlertMutedTill = nil
            }

            if let mutedTill = viewModel.pressureAlertMutedTill,
               mutedTill < Date() {
                viewModel.pressureAlertMutedTill = nil
            }

            if let mutedTill = viewModel.signalAlertMutedTill,
               mutedTill < Date() {
                viewModel.signalAlertMutedTill = nil
            }

            if let mutedTill = viewModel.carbonDioxideAlertMutedTill,
               mutedTill < Date() {
                viewModel.carbonDioxideAlertMutedTill = nil
            }

            if let mutedTill = viewModel.pMatter1AlertMutedTill,
               mutedTill < Date() {
                viewModel.pMatter1AlertMutedTill = nil
            }

            if let mutedTill = viewModel.pMatter25AlertMutedTill,
               mutedTill < Date() {
                viewModel.pMatter25AlertMutedTill = nil
            }

            if let mutedTill = viewModel.pMatter4AlertMutedTill,
               mutedTill < Date() {
                viewModel.pMatter4AlertMutedTill = nil
            }

            if let mutedTill = viewModel.pMatter10AlertMutedTill,
               mutedTill < Date() {
                viewModel.pMatter10AlertMutedTill = nil
            }

            if let mutedTill = viewModel.vocAlertMutedTill,
               mutedTill < Date() {
                viewModel.vocAlertMutedTill = nil
            }

            if let mutedTill = viewModel.noxAlertMutedTill,
               mutedTill < Date() {
                viewModel.noxAlertMutedTill = nil
            }

            if let mutedTill = viewModel.soundAlertMutedTill,
               mutedTill < Date() {
                viewModel.soundAlertMutedTill = nil
            }

            if let mutedTill = viewModel.luminosityAlertMutedTill,
               mutedTill < Date() {
                viewModel.luminosityAlertMutedTill = nil
            }

            if let mutedTill = viewModel.connectionAlertMutedTill,
               mutedTill < Date() {
                viewModel.connectionAlertMutedTill = nil
            }

            if let mutedTill = viewModel.movementAlertMutedTill,
               mutedTill < Date() {
                viewModel.movementAlertMutedTill = nil
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func updateMutedTill(
        of type: AlertType,
        for uuid: String,
        viewModel: CardsViewModel
    ) {
        let date = alertService.mutedTill(type: type, for: uuid)

        switch type {
        case .temperature:
            viewModel.temperatureAlertMutedTill = date
        case .relativeHumidity:
            viewModel.relativeHumidityAlertMutedTill = date
        case .pressure:
            viewModel.pressureAlertMutedTill = date
        case .signal:
            viewModel.signalAlertMutedTill = date
        case .carbonDioxide:
            viewModel.carbonDioxideAlertMutedTill = date
        case .pMatter1:
            viewModel.pMatter1AlertMutedTill = date
        case .pMatter25:
            viewModel.pMatter25AlertMutedTill = date
        case .pMatter4:
            viewModel.pMatter4AlertMutedTill = date
        case .pMatter10:
            viewModel.pMatter10AlertMutedTill = date
        case .voc:
            viewModel.vocAlertMutedTill = date
        case .nox:
            viewModel.noxAlertMutedTill = date
        case .sound:
            viewModel.soundAlertMutedTill = date
        case .luminosity:
            viewModel.luminosityAlertMutedTill = date
        case .connection:
            viewModel.connectionAlertMutedTill = date
        case .movement:
            viewModel.movementAlertMutedTill = date
        default:
            // Should never be here
            viewModel.temperatureAlertMutedTill = date
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func updateIsOnState(
        of type: AlertType,
        for uuid: String,
        viewModel: CardsViewModel
    ) {
        let isOn = alertService.isOn(type: type, for: uuid)

        switch type {
        case .temperature:
            viewModel.isTemperatureAlertOn = isOn
        case .relativeHumidity:
            viewModel.isRelativeHumidityAlertOn = isOn
        case .pressure:
            viewModel.isPressureAlertOn = isOn
        case .signal:
            viewModel.isSignalAlertOn = isOn
        case .carbonDioxide:
            viewModel.isCarbonDioxideAlertOn = isOn
        case .pMatter1:
            viewModel.isPMatter1AlertOn = isOn
        case .pMatter25:
            viewModel.isPMatter25AlertOn = isOn
        case .pMatter4:
            viewModel.isPMatter4AlertOn = isOn
        case .pMatter10:
            viewModel.isPMatter10AlertOn = isOn
        case .voc:
            viewModel.isVOCAlertOn = isOn
        case .nox:
            viewModel.isNOXAlertOn = isOn
        case .sound:
            viewModel.isSoundAlertOn = isOn
        case .luminosity:
            viewModel.isLuminosityAlertOn = isOn
        case .connection:
            viewModel.isConnectionAlertOn = isOn
        case .movement:
            viewModel.isMovementAlertOn = isOn
        case .cloudConnection:
            viewModel.isCloudConnectionAlertOn = isOn
        default:
            // Should never be here, but fallback:
            viewModel.isTemperatureAlertOn = isOn
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

    private func startObservingCloudLatestDataSyncNotification() {
        latestDataSyncToken?.invalidate()
        latestDataSyncToken = nil
        latestDataSyncToken = NotificationCenter
            .default
            .addObserver(
                forName: .NetworkSyncLatestDataDidChangeStatus,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self,
                          let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                          let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                          mac.any == sSelf.currentVisibleViewModel?.mac,
                          !sSelf.showingChart
                    else {
                        return
                    }

                    switch status {
                    case .syncing:
                        sSelf.view?.isRefreshing = true
                    default:
                        sSelf.view?.isRefreshing = false
                    }
                }
            )
    }

    private func startObservingCloudHistorySyncNotification() {
        historySyncToken?.invalidate()
        historySyncToken = nil
        historySyncToken = NotificationCenter
            .default
            .addObserver(
                forName: .NetworkSyncHistoryDidChangeStatus,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self,
                          let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                          let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                          mac.any == sSelf.currentVisibleViewModel?.mac,
                          sSelf.showingChart
                    else {
                        return
                    }

                    switch status {
                    case .syncing:
                        sSelf.view?.isRefreshing = true
                    default:
                        sSelf.view?.isRefreshing = false
                    }
                }
            )
    }
}

// swiftlint:enable file_length
