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
import DGCharts

class NewTagChartEntity: NSObject, ObservableObject {
    let id = UUID()

    @Published var ruuviTagId: String
    @Published var chartType: MeasurementType
    @Published var chartData: LineChartData?
    @Published var lowerAlertValue: Double?
    @Published var upperAlertValue: Double?
    @Published var dataSet: [ChartDataEntry] = []

    init(
        ruuviTagId: String,
        chartType: MeasurementType,
        chartData: LineChartData? = nil,
        upperAlertValue: Double? = nil,
        lowerAlertValue: Double? = nil
    ) {
        self.ruuviTagId = ruuviTagId
        self.chartType = chartType
        self.chartData = chartData
        self.upperAlertValue = upperAlertValue
        self.lowerAlertValue = lowerAlertValue
    }
}

class NewCardsPresenter {

    weak var view: NewCardsViewInput?
    var router: CardsRouterInput!
    var interactor: NewCardsInteractorInput!
    var errorPresenter: ErrorPresenter!
    var settings: RuuviLocalSettings!
    var flags: RuuviLocalFlags!
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
    var measurementService: RuuviServiceMeasurement! {
        didSet {
            measurementService?.add(self)
        }
    }

    private var sensorSettings = [SensorSettings]()

    private var isBluetoothPermissionGranted: Bool {
        CBCentralManager.authorization == .allowedAlways
    }

    private var graphData: [RuuviMeasurement] = []
    private var graphDataSource: [NewTagChartEntity] = []
    private var newGraphPoints: [NewTagChartEntity] = []
    private var graphModules: [MeasurementType] = []

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
    private var startKeepingConnectionToken: NSObjectProtocol?
    private var stopKeepingConnectionToken: NSObjectProtocol?
    private var readRSSIToken: NSObjectProtocol?
    private var readRSSIIntervalToken: NSObjectProtocol?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var cloudModeToken: NSObjectProtocol?
    private var sensorOrderChangeToken: NSObjectProtocol?
    private var mutedTillTimer: Timer?
}

extension NewCardsPresenter {
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
        startMutedTillTimer()
        startObservingSensorOrderChanges()

        reloadMutedTill()
        startObservingBluetoothState()
    }

    private func updateVisibleCard(
        from viewModel: CardsViewModel?,
        openChart: Bool = false,
        triggerScroll: Bool = false
    ) {
        if let index = view?.state.viewModels.firstIndex(where: {
            ($0.luid != nil && $0.luid == viewModel?.luid) ||
                ($0.mac != nil && $0.mac == viewModel?.mac)
        }) {
            view?.state.currentPage = index
        }

        startObservingVisibleTag()
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func startObservingRuuviTags() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            guard let sSelf = self else { return }
            switch change {
            case let .insert(sensor):
                sSelf.notifyRestartAdvertisementDaemon()
                sSelf.notifyRestartHeartBeatDaemon()
                sSelf.view?.state.ruuviTags.append(sensor.any)
                sSelf.syncViewModels()
                if let viewModel = sSelf.view?.state.viewModels.first(where: {
                    ($0.luid != nil && $0.luid == sensor.luid?.any)
                        || ($0.mac != nil && $0.mac == sensor.macId?.any)
                }) {
                    sSelf.updateVisibleCard(
                        from: viewModel,
                        triggerScroll: true
                    )
                }
            case let .update(sensor):
                guard let sSelf = self else { return }
                if let index = sSelf.view?.state.ruuviTags
                    .firstIndex(
                        where: {
                            ($0.macId != nil && $0.macId?.any == sensor.macId?.any)
                                || ($0.luid != nil && $0.luid?.any == sensor.luid?.any)
                        }) {
                    sSelf.view?.state.ruuviTags[index] = sensor
                    sSelf.syncViewModels()
                }

            case let .delete(sensor):
                sSelf.view?.state.ruuviTags
                    .removeAll(where: { $0.id == sensor.id })
                sSelf.syncViewModels()
                // If a sensor is deleted, and there's no more sensor take
                // user to dashboard.
                guard sSelf.view?.state.viewModels.count ?? 0 > 0
                else {
//                    sSelf.viewShouldDismiss()
                    return
                }

                // If the visible sensor is deleted, sroll to the first sensor
                // in the list and make it visible sensor.
                // Don't change scroll position if a sensor is deleted(via sync or otherwise)
                // which is not the currently visible one.
                if let first = sSelf.view?.state.viewModels.first {
                    sSelf.updateVisibleCard(from: first, triggerScroll: true)
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
        for viewModel in view?.state.viewModels ?? [] {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = view?.state.ruuviTags.first(where: { $0.id == viewModel.id }) {
                let token = ruuviReactor.observeLatest(ruuviTagSensor) { [weak self] changes in
                    if case let .update(anyRecord) = changes,
                       let viewModel = self?.view?.state.viewModels
                           .first(where: {
                               ($0.luid != nil && ($0.luid == anyRecord?.luid?.any))
                                   || ($0.mac != nil && ($0.mac == anyRecord?.macId?.any))
                           }),
                           let record = anyRecord {
                        let sensorSettings = self?.view?.state.sensorSettings
                            .first(where: {
                                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
                                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
                            })
                        let sensorRecord = record.with(sensorSettings: sensorSettings)
                        viewModel.update(sensorRecord)
                        self?.processAlert(record: sensorRecord, viewModel: viewModel)
                    }
                }
                ruuviTagObserveLastRecordTokens.append(token)
            }
        }
    }

    private func startListeningToRuuviTagsAlertStatus() {
        view?.state.ruuviTags.forEach { ruuviTag in
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
                            sSelf.view?.state.viewModels.filter {
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
        guard let viewModel = view?.state.viewModels.first(
            where: { $0.luid == tag.uuid.luid.any }
        )
        else {
            return
        }
        let sensorSettings = view?.state.sensorSettings
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
        alertHandler.process(record: record, trigger: false)
    }

    private func updateSensorSettings(
        _ updatedSensorSettings: SensorSettings,
        _ ruuviTagSensor: AnyRuuviTagSensor
    ) {
        if let updateIndex = view?.state.sensorSettings.firstIndex(
            where: { $0.id == updatedSensorSettings.id }
        ) {
            view?.state.sensorSettings[updateIndex] = updatedSensorSettings
            if let viewModel = view?.state.viewModels.first(where: {
                $0.id == ruuviTagSensor.id
            }) {
                notifySensorSettingsUpdate(
                    sensorSettings: updatedSensorSettings,
                    viewModel: viewModel
                )
            }
        } else {
            view?.state.sensorSettings.append(updatedSensorSettings)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func observeSensorSettings() {
        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        for viewModel in view?.state.viewModels ?? [] {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = view?.state.ruuviTags.first(where: { $0.id == viewModel.id }) {
                sensorSettingsTokens.append(
                    ruuviReactor.observe(ruuviTagSensor) { [weak self] change in
                        guard let sSelf = self else { return }
                        switch change {
                        case let .insert(sensorSettings):
                            self?.view?.state.sensorSettings
                                .append(sensorSettings)
                            if let viewModel = sSelf.view?.state.viewModels.first(where: {
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
                                self?.view?.state.sensorSettings.remove(at: deleteIndex)
                            }
                            if let viewModel = sSelf.view?.state.viewModels.first(where: {
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
    }

    private func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { observer, state in
            if state != .poweredOn || !self.isBluetoothPermissionGranted {
//                observer.view?.showBluetoothDisabled(
//                    userDeclined: !self.isBluetoothPermissionGranted)
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

                    let viewModel = sSelf.view?.state.viewModels
                        .first(where: { $0.luid != nil && $0.luid == luid?.any })
                    ?? sSelf.view?.state.viewModels
                        .first(where: { $0.mac != nil && $0.mac == macId?.any })
                    if let viewModel {
                        let ruuviTag = sSelf.view?.state.ruuviTags
                            .first(where: { $0.luid != nil && $0.luid?.any == luid?.any })
                        ?? sSelf.view?.state.ruuviTags
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
                       let viewModel = self?.view?.state.viewModels.first(
                        where: { $0.luid == uuid.luid.any
                        }) {
                        viewModel.isConnected = true
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
                       let viewModel = self?.view?.state.viewModels.first(
                        where: { $0.luid == uuid.luid.any
                        }) {
                        viewModel.isConnected = false
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
                    guard let sSelf = self else { return }
                    DispatchQueue.main.async {
                        // Keep a reference to the current page before reordering
                        // the viewModels array. This will be used to scroll to the
                        // same page after reordering.
                        if let currentPage = sSelf.view?.state.currentPage,
                           let visibleViewModel = sSelf.view?.state.viewModels[currentPage] {

                            sSelf.view?.state.viewModels = sSelf
                                .reorder(sSelf.view?.state.viewModels)

                            if let index = sSelf.view?.state.viewModels.firstIndex(where: {
                                ($0.luid != nil && $0.luid == visibleViewModel.luid) ||
                                    ($0.mac != nil && $0.mac == visibleViewModel.mac)
                            }) {
                                sSelf.view?.state.currentPage = index
                            }
                        }
                    }
                }
            )
    }

    /// The method handles all the operations when cloud mode toggle is turned on/off
    private func handleCloudModeState() {
        // Sync with cloud if cloud mode is turned on
        if settings.cloudModeEnabled {
            for viewModel in view?.state.viewModels ?? [] where viewModel.isCloud {
                viewModel.isConnected = false
            }
        }
    }

    // ACTIONS
    private func syncViewModels() {
        let ruuviViewModels = view?.state.ruuviTags.compactMap { ruuviTag -> CardsViewModel in
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
                viewModel.networkSyncStatus = localSyncState.getSyncStatus(for: macId)
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
            if let previousRecord = view?.state.viewModels.first(where: {
                $0.id == ruuviTag.id
            })?.latestMeasurement {
                viewModel.update(previousRecord)
            }
            syncAlerts(ruuviTag: ruuviTag, viewModel: viewModel)
            let op = ruuviStorage.readLatest(ruuviTag)
            op.on { [weak self] record in
                if let record {
                    viewModel.update(record)
                    self?.processAlert(record: record, viewModel: viewModel)
                }
            }

            return viewModel
        }

        view?.state.viewModels = reorder(ruuviViewModels)

//        guard viewModels.count > 0
//        else {
//            output?.cardsViewDidDismiss(module: self)
//            return
//        }
    }

    private func reorder(_ viewModels: [CardsViewModel]?) -> [CardsViewModel] {
        let sortedSensors: [String] = settings.dashboardSensorOrder
        let sortedAndUniqueArray = viewModels?.reduce(
            into: [CardsViewModel]()
        ) { result, element in
            if !result.contains(element) {
                result.append(element)
            }
        }

        if !sortedSensors.isEmpty {
            return sortedAndUniqueArray?.sorted { (first, second) -> Bool in
                guard let firstMacId = first.mac?.value,
                      let secondMacId = second.mac?.value else { return false }
                let firstIndex = sortedSensors.firstIndex(of: firstMacId) ?? Int.max
                let secondIndex = sortedSensors.firstIndex(of: secondMacId) ?? Int.max
                return firstIndex < secondIndex
            } ?? []
        } else {
            return sortedAndUniqueArray?.sorted { (first, second) -> Bool in
                let firstName = first.name.lowercased()
                let secondName = second.name.lowercased()
                return firstName < secondName
            } ?? []
        }
    }

    private func openTagSettingsScreens(viewModel: CardsViewModel) {
//        let sensorSettings = sensorSettings
//            .first(where: {
//                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
//                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
//            })
//        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id }) {
//            router.openTagSettings(
//                ruuviTag: ruuviTag,
//                latestMeasurement: viewModel.latestMeasurement,
//                sensorSettings: sensorSettings,
//                output: self
//            )
//        }
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
        router.dismiss()
    }
}

// MARK: - CardsViewOutput

//extension NewCardsPresenter: NewCardsViewOutput {
//    func viewDidLoad() {
//        startObservingAppState()
//        startMutedTillTimer()
//        startObservingSensorOrderChanges()
//    }
//
//    func viewWillAppear() {
//        guard viewModels.count > 0
//        else {
//            return
//        }
//        view?.scroll(to: visibleViewModelIndex)
//        startObservingBluetoothState()
//    }
//
//    func viewDidAppear() {
//        // No op.
//    }
//
//    func viewWillDisappear() {
//        stopObservingBluetoothState()
//    }
//
//    func viewDidTriggerSettings(for viewModel: CardsViewModel) {
//        if viewModel.type == .ruuvi {
//            if let luid = viewModel.luid {
//                if settings.keepConnectionDialogWasShown(for: luid)
//                    || background.isConnected(uuid: luid.value)
//                    || !viewModel.isConnectable
//                    || !viewModel.isOwner
//                    || (settings.cloudModeEnabled && viewModel.isCloud) {
//                    openTagSettingsScreens(viewModel: viewModel)
//                } else {
//                    view?.showKeepConnectionDialogSettings(for: viewModel)
//                }
//            } else {
//                openTagSettingsScreens(viewModel: viewModel)
//            }
//        }
//    }
//
//    func viewDidTriggerShowChart(for viewModel: CardsViewModel) {
//        if let luid = viewModel.luid {
//            if settings.keepConnectionDialogWasShown(for: luid)
//                || background.isConnected(uuid: luid.value)
//                || !viewModel.isConnectable
//                || !viewModel.isOwner
//                || (settings.cloudModeEnabled && viewModel.isCloud) {
//                if let sensor = ruuviTags
//                    .first(where: {
//                        $0.macId != nil && ($0.macId?.any == viewModel.mac)
//                    }) {
//                    showCharts(for: sensor)
//                }
//            } else {
//                view?.showKeepConnectionDialogChart(for: viewModel)
//            }
//        } else if viewModel.mac != nil {
//            if let sensor = ruuviTags
//                .first(where: {
//                    $0.macId != nil && ($0.macId?.any == viewModel.mac)
//                }) {
//                showCharts(for: sensor)
//            }
//        } else {
//            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
//        }
//    }
//
//    func viewDidTriggerNavigateChart(to viewModel: CardsViewModel) {
//        if let tagCharts, let sensor = ruuviTags
//            .first(where: {
//                $0.macId != nil && ($0.macId?.any == viewModel.mac)
//            }) {
//            tagCharts.scrollTo(ruuviTag: sensor)
//        }
//    }
//
//    func viewDidTriggerDismissChart(
//        for _: CardsViewModel,
//        dismissParent: Bool
//    ) {
//        tagCharts?.notifyDismissInstruction(dismissParent: dismissParent)
//    }
//
//    private func showCharts(for sensor: AnyRuuviTagSensor) {
//        let factory: TagChartsModuleFactory = TagChartsModuleFactoryImpl()
//        let module = factory.create()
//        tagChartsModule = module
//        if let tagChartsPresenter = module.output as? TagChartsViewModuleInput {
//            tagCharts = tagChartsPresenter
//            tagCharts?.configure(output: self)
//            tagCharts?.configure(ruuviTag: sensor)
//            view?.showChart(module: module)
//        }
//    }
//
//    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel) {
//        if let luid = viewModel.luid {
//            settings.setKeepConnectionDialogWasShown(for: luid)
//            if let sensor = ruuviTags
//                .first(where: {
//                    $0.macId != nil && ($0.macId?.any == viewModel.mac)
//                }) {
//                showCharts(for: sensor)
//            }
//        } else {
//            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
//        }
//    }
//
//    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel) {
//        if let luid = viewModel.luid {
//            connectionPersistence.setKeepConnection(true, for: luid)
//            settings.setKeepConnectionDialogWasShown(for: luid)
//            if let sensor = ruuviTags
//                .first(where: {
//                    $0.macId != nil && ($0.macId?.any == viewModel.mac)
//                }) {
//                showCharts(for: sensor)
//            }
//        } else {
//            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
//        }
//    }
//
//    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
//        if let luid = viewModel.luid {
//            settings.setKeepConnectionDialogWasShown(for: luid)
//            openTagSettingsScreens(viewModel: viewModel)
//        } else {
//            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
//        }
//    }
//
//    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel) {
//        if let luid = viewModel.luid {
//            connectionPersistence.setKeepConnection(true, for: luid)
//            settings.setKeepConnectionDialogWasShown(for: luid)
//            openTagSettingsScreens(viewModel: viewModel)
//        } else {
//            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
//        }
//    }
//
//    func viewDidTriggerFirmwareUpdateDialog(for viewModel: CardsViewModel) {
//        guard let luid = viewModel.luid,
//              let version = viewModel.version, version < 5,
//              viewModel.isOwner,
//              featureToggleService.isEnabled(.legacyFirmwareUpdatePopup)
//        else {
//            return
//        }
//        if !settings.firmwareUpdateDialogWasShown(for: luid) {
//            view?.showFirmwareUpdateDialog(for: viewModel)
//        }
//    }
//
//    func viewDidConfirmFirmwareUpdate(for viewModel: CardsViewModel) {
//        if let sensor = ruuviTags
//            .first(where: {
//                $0.luid != nil && ($0.luid?.any == viewModel.luid)
//            }) {
//            router.openUpdateFirmware(ruuviTag: sensor)
//        }
//    }
//
//    func viewDidIgnoreFirmwareUpdateDialog(for viewModel: CardsViewModel) {
//        view?.showFirmwareDismissConfirmationUpdateDialog(for: viewModel)
//    }
//
//    func viewDidDismissFirmwareUpdateDialog(for viewModel: CardsViewModel) {
//        guard let luid = viewModel.luid else { return }
//        settings.setFirmwareUpdateDialogWasShown(for: luid)
//    }
//
//    func viewDidScroll(to viewModel: CardsViewModel) {
//        if let sensor = ruuviTags
//            .first(where: {
//                ($0.luid != nil && ($0.luid?.any == viewModel.luid))
//                    || ($0.macId != nil && ($0.macId?.any == viewModel.mac))
//            }) {
//            updateVisibleCard(from: viewModel)
//            checkFirmwareVersion(for: sensor)
//        }
//    }
//
//    func viewShouldDismiss() {
//        view?.dismissChart()
//        output?.cardsViewDidDismiss(module: self)
//    }
//}

//// MARK: - TagChartsModuleOutput
//
//extension NewCardsPresenter: NewTagChartsViewModuleOutput {
//    func tagChartSafeToClose(
//        module: TagChartsViewModuleInput,
//        dismissParent: Bool
//    ) {
//        module.dismiss(completion: { [weak self] in
//            if dismissParent {
//                self?.viewShouldDismiss()
//            } else {
//                self?.view?.dismissChart()
//            }
//        })
//    }
//
//    func tagChartSafeToSwipe(
//        to ruuviTag: AnyRuuviTagSensor, module _: TagChartsViewModuleInput
//    ) {
//        if let viewModel = viewModels.first(where: {
//            ($0.luid != nil && $0.luid == ruuviTag.luid?.any)
//                || ($0.mac != nil && $0.mac == ruuviTag.macId?.any)
//        }) {
//            updateVisibleCard(
//                from: viewModel,
//                triggerScroll: true
//            )
//            view?.scroll(to: visibleViewModelIndex)
//        }
//    }
//}

// MARK: - RuuviNotifierObserver

extension NewCardsPresenter: RuuviNotifierObserver {
    func ruuvi(notifier _: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        view?.state.viewModels
            .filter { $0.luid?.value == uuid || $0.mac?.value == uuid }
            .forEach { viewModel in
                let newValue: AlertState = isTriggered ? .firing : .registered
                viewModel.alertState = newValue
            }
    }
}

// MARK: - TagSettingsModuleOutput

//extension NewCardsPresenter: TagSettingsModuleOutput {
//    func tagSettingsDidDeleteTag(
//        module: TagSettingsModuleInput,
//        ruuviTag: RuuviTagSensor
//    ) {
//        module.dismiss(completion: { [weak self] in
//            guard let self else { return }
//            view?.dismissChart()
//            output?.cardsViewDidRefresh(module: self)
//            if let index = viewModels.firstIndex(where: {
//                ($0.luid != nil && $0.luid == ruuviTag.luid?.any) ||
//                    ($0.mac != nil && $0.mac == ruuviTag.macId?.any)
//            }) {
//                viewModels.remove(at: index)
//                view?.viewModels = viewModels
//            }
//
//            if viewModels.count > 0,
//               let first = viewModels.first {
//                updateVisibleCard(from: first, triggerScroll: true)
//            } else {
//                viewShouldDismiss()
//            }
//        })
//    }
//
//    func tagSettingsDidDismiss(module: TagSettingsModuleInput) {
//        module.dismiss(completion: nil)
//    }
//}

// MARK: - Private

extension NewCardsPresenter {

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
            viewModel.temperatureAlertState,
            viewModel.relativeHumidityAlertState,
            viewModel.pressureAlertState,
            viewModel.signalAlertState,
            viewModel.carbonDioxideAlertState,
            viewModel.pMatter1AlertState,
            viewModel.pMatter2_5AlertState,
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
                viewModel.alertState = .firing
            } else {
                viewModel.alertState = .registered
            }
        } else {
            viewModel.alertState = .empty
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
        pMatter2_5: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter2_5 = alertService
            .alert(for: ruuviTag, of: pMatter2_5) {
            viewModel.isPMatter2_5AlertOn = true
        } else {
            viewModel.isPMatter2_5AlertOn = false
        }
        viewModel.pMatter2_5AlertMutedTill =
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
        for viewModel in view?.state.viewModels ?? [] {
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

            if let mutedTill = viewModel.pMatter2_5AlertMutedTill,
               mutedTill < Date() {
                viewModel.pMatter2_5AlertMutedTill = nil
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
        case .pMatter2_5:
            viewModel.pMatter2_5AlertMutedTill = date
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
        case .pMatter2_5:
            viewModel.isPMatter2_5AlertOn = isOn
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
}

extension NewCardsPresenter: NewCardsViewOutput {
    func showGraphForViewModel(_ viewModel: CardsViewModel) {
        if let ruuviTagSensor = view?.state.ruuviTags.first(where: { $0.id == viewModel.id }),
           let sensorSettings = view?.state.sensorSettings
               .first(where: {
                   ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
                       || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
               }) {

            view?.state.graphLoadingState = .loading

            interactor.configure(
                withTag: ruuviTagSensor,
                andSettings: sensorSettings
            )
        }
    }

    func clearGraphForViewModel(_ viewModel: CardsViewModel, confirmed: Bool) {
        if confirmed {
            if let ruuviTagSensor = view?.state.ruuviTags.first(where: { $0.id == viewModel.id }) {
               view?.state.graphLoadingState = .loading
               interactor.deleteAllRecords(for: ruuviTagSensor)
                   .on(failure: { [weak self] error in
                       self?.errorPresenter.present(error: error)
                   }, completion: { [weak self] in
                       self?.view?.state.graphLoadingState = .finished
                   })
            }
        }
    }
}

extension NewCardsPresenter: NewCardsModuleInput {
    // swiftlint:disable:next function_parameter_count
    func configure(
        viewModels: [CardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        scrollTo: CardsViewModel?,
        openWith: SensorCardSelectedTab,
        output: CardsModuleOutput
    ) {
        view?.state.viewModels = viewModels
        view?.state.ruuviTags = ruuviTagSensors
        view?.state.sensorSettings = sensorSettings

        if let scrollTo = scrollTo,
            let index = viewModels.firstIndex(of: scrollTo) {
            view?.state.currentPage = index
        }

        view?.state.chartViewModel = ChartContainerViewModel(
            settings: settings,
            flags: flags,
            measurementService: measurementService
        )

        startObservingVisibleTag()
    }

    func dismiss(completion: (() -> Void)?) {

    }
}

extension NewCardsPresenter: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {

    }
}

extension NewCardsPresenter: CardsModuleOutput {
    func cardsViewDidRefresh(module: CardsModuleInput) {

    }

    func cardsViewDidDismiss(module: CardsModuleInput) {

    }
}

// MARK: Charts
extension NewCardsPresenter: NewCardsInteractorOutput {

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func insertMeasurements(_ newValues: [RuuviMeasurement], for sensor: RuuviTagSensor) {
        guard view != nil else { return }
        graphData = interactor.ruuviTagData

        var temparatureData = [ChartDataEntry]()
        var humidityData = [ChartDataEntry]()
        var pressureData = [ChartDataEntry]()
        var aqiData = [ChartDataEntry]()
        var co2Data = [ChartDataEntry]()
        var pm25Data = [ChartDataEntry]()
        var pm10Data = [ChartDataEntry]()
        var vocData = [ChartDataEntry]()
        var noxData = [ChartDataEntry]()
        var luminosityData = [ChartDataEntry]()
        var soundData = [ChartDataEntry]()

        let sensorSettings = settingsForSensor(sensor)
        for measurement in newValues {
            // Temperature
            if let temperatureEntry = chartEntry(
                for: measurement,
                type: .temperature,
                sensorSettings: sensorSettings
            ) {
                temparatureData
                    .append(
                        temperatureEntry
                    )
            }

            // Humidty
            if let humidityEntry = chartEntry(
                for: measurement,
                type: .humidity,
                sensorSettings: sensorSettings
            ) {
                humidityData
                    .append(
                        humidityEntry
                    )
            }

            // Pressure
            if let pressureEntry = chartEntry(
                for: measurement,
                type: .pressure,
                sensorSettings: sensorSettings
            ) {
                pressureData
                    .append(
                        pressureEntry
                    )
            }

            // AQI
            if let aqiEntry = chartEntry(
                for: measurement,
                type: .aqi,
                sensorSettings: sensorSettings
            ) {
                aqiData
                    .append(
                        aqiEntry
                    )
            }

            // Carbon Dioxide
            if let co2Entry = chartEntry(
                for: measurement,
                type: .co2,
                sensorSettings: sensorSettings
            ) {
                co2Data
                    .append(
                        co2Entry
                    )
            }

            // PM2.5
            if let pm25Entry = chartEntry(
                for: measurement,
                type: .pm25,
                sensorSettings: sensorSettings
            ) {
                pm25Data
                    .append(
                        pm25Entry
                    )
            }

            // PM10
            if let pm10Entry = chartEntry(
                for: measurement,
                type: .pm10,
                sensorSettings: sensorSettings
            ) {
                pm10Data
                    .append(
                        pm10Entry
                    )
            }

            // VOC
            if let vocEntry = chartEntry(
                for: measurement,
                type: .voc,
                sensorSettings: sensorSettings
            ) {
                vocData
                    .append(
                        vocEntry
                    )
            }

            // NOx
            if let noxEntry = chartEntry(
                for: measurement,
                type: .nox,
                sensorSettings: sensorSettings
            ) {
                noxData
                    .append(
                        noxEntry
                    )
            }

            // Luminosity
            if let luminosityEntry = chartEntry(
                for: measurement,
                type: .luminosity,
                sensorSettings: sensorSettings
            ) {
                luminosityData.append(luminosityEntry)
            }

            // Sound
            if let soundEntry = chartEntry(
                for: measurement,
                type: .sound,
                sensorSettings: sensorSettings
            ) {
                soundData.append(soundEntry)
            }
        }

        // Update new measurements on the chart
        view?.updateChartViewData(
            for: sensor,
            temperatureEntries: temparatureData,
            humidityEntries: humidityData,
            pressureEntries: pressureData,
            aqiEntries: aqiData,
            co2Entries: co2Data,
            pm10Entries: pm25Data,
            pm25Entries: pm10Data,
            vocEntries: vocData,
            noxEntries: noxData,
            luminosityEntries: luminosityData,
            soundEntries: soundData,
            isFirstEntry: graphData.count == 1,
            settings: settings,
            flags: flags
        )

        // Update the latest measurement label.
        if let lastMeasurement = newValues.last {
            let sensorSettings = settingsForSensor(sensor)
            view?.updateLatestMeasurement(
                for: sensor,
                temperature: chartEntry(
                    for: lastMeasurement,
                    type: .temperature,
                    sensorSettings: sensorSettings
                ),
                humidity: chartEntry(
                    for: lastMeasurement,
                    type: .humidity,
                    sensorSettings: sensorSettings
                ),
                pressure: chartEntry(
                    for: lastMeasurement,
                    type: .pressure,
                    sensorSettings: sensorSettings
                ),
                aqi: chartEntry(
                    for: lastMeasurement,
                    type: .aqi,
                    sensorSettings: sensorSettings
                ),
                co2: chartEntry(
                    for: lastMeasurement,
                    type: .co2,
                    sensorSettings: sensorSettings
                ),
                pm10: chartEntry(
                    for: lastMeasurement,
                    type: .pm10,
                    sensorSettings: sensorSettings
                ),
                pm25: chartEntry(
                    for: lastMeasurement,
                    type: .pm25,
                    sensorSettings: sensorSettings
                ),
                voc: chartEntry(
                    for: lastMeasurement,
                    type: .voc,
                    sensorSettings: sensorSettings
                ),
                nox: chartEntry(
                    for: lastMeasurement,
                    type: .nox,
                    sensorSettings: sensorSettings
                ),
                luminosity: chartEntry(
                    for: lastMeasurement,
                    type: .luminosity,
                    sensorSettings: sensorSettings
                ),
                sound: chartEntry(
                    for: lastMeasurement,
                    type: .sound,
                    sensorSettings: sensorSettings
                ),
                settings: settings
            )
        }
    }

    func updateLatestRecord(_ record: RuuviTagSensorRecord, for sensor: RuuviTagSensor) {
        // Do something if needed.
        // TODO: Make it observe all sensor
    }

    func createChartModules(from: [MeasurementType], for sensor: RuuviTagSensor) {
        guard view != nil else { return }
        graphModules = from
        view?.createChartViews(from: graphModules,
                               for: sensor)
    }

    func interactorDidError(_ error: RUError, for sensor: RuuviTagSensor) {
        errorPresenter.present(error: error)
    }

    func interactorDidUpdate(sensor: AnyRuuviTagSensor) {
        graphData = interactor.ruuviTagData
        createChartData(for: sensor)
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func createChartData(for ruuviTag: RuuviTagSensor) {
        guard view != nil else { return }
        graphDataSource.removeAll()

        var temparatureData = [ChartDataEntry]()
        var humidityData = [ChartDataEntry]()
        var pressureData = [ChartDataEntry]()
        var aqiData = [ChartDataEntry]()
        var co2Data = [ChartDataEntry]()
        var pm25Data = [ChartDataEntry]()
        var pm10Data = [ChartDataEntry]()
        var vocData = [ChartDataEntry]()
        var noxData = [ChartDataEntry]()
        var luminosityData = [ChartDataEntry]()
        var soundData = [ChartDataEntry]()

        for measurement in graphData {
            let sensorSettings = settingsForSensor(ruuviTag)
            // Temperature
            if let temperatureEntry = chartEntry(
                for: measurement,
                type: .temperature,
                sensorSettings: sensorSettings
            ) {
                temparatureData
                    .append(
                        temperatureEntry
                    )
            }

            // Humidty
            if let humidityEntry = chartEntry(
                for: measurement,
                type: .humidity,
                sensorSettings: sensorSettings
            ) {
                humidityData
                    .append(
                        humidityEntry
                    )
            }

            // Pressure
            if let pressureEntry = chartEntry(
                for: measurement,
                type: .pressure,
                sensorSettings: sensorSettings
            ) {
                pressureData
                    .append(
                        pressureEntry
                    )
            }

            // AQI
            if let aqiEntry = chartEntry(
                for: measurement,
                type: .aqi,
                sensorSettings: sensorSettings
            ) {
                aqiData
                    .append(
                        aqiEntry
                    )
            }

            // Carbon Dioxide
            if let co2Entry = chartEntry(
                for: measurement,
                type: .co2,
                sensorSettings: sensorSettings
            ) {
                co2Data
                    .append(
                        co2Entry
                    )
            }

            // PM2.5
            if let pm25Entry = chartEntry(
                for: measurement,
                type: .pm25,
                sensorSettings: sensorSettings
            ) {
                pm25Data
                    .append(
                        pm25Entry
                    )
            }

            // PM10
            if let pm10Entry = chartEntry(
                for: measurement,
                type: .pm10,
                sensorSettings: sensorSettings
            ) {
                pm10Data
                    .append(
                        pm10Entry
                    )
            }

            // VOC
            if let vocEntry = chartEntry(
                for: measurement,
                type: .voc,
                sensorSettings: sensorSettings
            ) {
                vocData
                    .append(
                        vocEntry
                    )
            }

            // NOx
            if let noxEntry = chartEntry(
                for: measurement,
                type: .nox,
                sensorSettings: sensorSettings
            ) {
                noxData.append(noxEntry)
            }

            // Luminosity
            if let luminosityEntry = chartEntry(
                for: measurement,
                type: .luminosity,
                sensorSettings: sensorSettings
            ) {
                luminosityData.append(luminosityEntry)
            }

            // Sound
            if let soundEntry = chartEntry(
                for: measurement,
                type: .sound,
                sensorSettings: sensorSettings
            ) {
                soundData.append(soundEntry)
            }
        }

        // Create datasets only if collection has at least one chart entry
        if temparatureData.count > 0 {
            let isOn = alertService.isOn(type: .temperature(lower: 0, upper: 0), for: ruuviTag)
            let temperatureDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperCelsius(for: ruuviTag)
                    .flatMap {
                        Temperature($0, unit: .celsius)
                    }.map { measurementService.double(for: $0) } : nil,
                entries: temparatureData,
                lowerAlertValue: isOn ? alertService.lowerCelsius(for: ruuviTag)
                    .flatMap {
                        Temperature($0, unit: .celsius)
                    }.map { measurementService.double(for: $0) } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let temperatureChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .temperature,
                chartData: LineChartData(
                    dataSet: temperatureDataSet
                ),
                upperAlertValue: isOn ? alertService
                    .upperCelsius(for: ruuviTag)
                    .flatMap {
                        Temperature($0, unit: .celsius)
                    }.map { measurementService.double(for: $0) } : nil,
                lowerAlertValue: isOn ? alertService.lowerCelsius(for: ruuviTag)
                    .flatMap {
                        Temperature($0, unit: .celsius)
                    }.map { measurementService.double(for: $0) } : nil
            )
            graphDataSource.append(temperatureChartData)
        }

        if humidityData.count > 0 {
            let isOn = alertService.isOn(type: .relativeHumidity(lower: 0, upper: 0), for: ruuviTag)
            let isRelative = measurementService.units.humidityUnit == .percent
            let humidityChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: (isOn && isRelative) ? alertService.upperRelativeHumidity(
                    for: ruuviTag
                ).map {
                    $0 * 100
                } : nil,
                entries: humidityData,
                lowerAlertValue: (isOn && isRelative) ? alertService.lowerRelativeHumidity(
                    for: ruuviTag
                ).map { $0 * 100 } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let humidityChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .humidity,
                chartData: LineChartData(dataSet: humidityChartDataSet),
                upperAlertValue: (
                    isOn && isRelative
                ) ? alertService
                    .upperRelativeHumidity(for: ruuviTag)
                    .map {
                        $0 * 100
                    } : nil,
                lowerAlertValue: (isOn && isRelative) ? alertService.lowerRelativeHumidity(
                    for: ruuviTag
                ).map { $0 * 100 } : nil
            )
            graphDataSource.append(humidityChartData)
        }

        if pressureData.count > 0 {
            let isOn = alertService.isOn(type: .pressure(lower: 0, upper: 0), for: ruuviTag)
            let pressureChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperPressure(for: ruuviTag)
                    .flatMap {
                        Pressure($0, unit: .hectopascals)
                    }.map { measurementService.double(for: $0) } : nil,
                entries: pressureData,
                lowerAlertValue: isOn ? alertService.lowerPressure(for: ruuviTag)
                    .flatMap {
                        Pressure($0, unit: .hectopascals)
                    }.map { measurementService.double(for: $0) } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let pressureChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .pressure,
                chartData: LineChartData(dataSet: pressureChartDataSet),
                upperAlertValue: isOn ? alertService.upperPressure(for: ruuviTag)
                    .flatMap {
                        Pressure($0, unit: .hectopascals)
                    }.map { measurementService.double(for: $0) } : nil,
                lowerAlertValue: isOn ? alertService.lowerPressure(for: ruuviTag)
                    .flatMap {
                        Pressure($0, unit: .hectopascals)
                    }.map { measurementService.double(for: $0) } : nil
            )
            graphDataSource.append(pressureChartData)
        }

        if aqiData.count > 0 {
            // TODO: Set up AQI Alert and Get Data from here
            let aqiChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: nil,
                entries: aqiData,
                lowerAlertValue: nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let aqiChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .aqi,
                chartData: LineChartData(dataSet: aqiChartDataSet),
                upperAlertValue: nil,
                lowerAlertValue: nil
            )
            graphDataSource.append(aqiChartData)
        }

        if co2Data.count > 0 {
            let isOn = alertService.isOn(
                type: .carbonDioxide(lower: 0, upper: 0),
                for: ruuviTag
            )
            let co2ChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperCarbonDioxide(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: co2Data,
                lowerAlertValue: isOn ? alertService
                    .lowerCarbonDioxide(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let co2ChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .co2,
                chartData: LineChartData(dataSet: co2ChartDataSet),
                upperAlertValue: isOn ? alertService
                    .upperCarbonDioxide(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                lowerAlertValue: isOn ? alertService.lowerCarbonDioxide(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            graphDataSource.append(co2ChartData)
        }

        if pm10Data.count > 0 {
            let isOn = alertService.isOn(
                type: .pMatter10(lower: 0, upper: 0),
                for: ruuviTag
            )
            let pm10ChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperPM10(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: pm10Data,
                lowerAlertValue: isOn ? alertService
                    .lowerPM10(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let pm10ChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .pm10,
                chartData: LineChartData(dataSet: pm10ChartDataSet),
                upperAlertValue: isOn ? alertService
                    .upperPM10(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                lowerAlertValue: isOn ? alertService.lowerPM10(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            graphDataSource.append(pm10ChartData)
        }

        if pm25Data.count > 0 {
            let isOn = alertService.isOn(
                type: .pMatter2_5(lower: 0, upper: 0),
                for: ruuviTag
            )
            let pm25ChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperPM2_5(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: pm25Data,
                lowerAlertValue: isOn ? alertService
                    .lowerPM2_5(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let pm25ChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .pm25,
                chartData: LineChartData(dataSet: pm25ChartDataSet),
                upperAlertValue: isOn ? alertService
                    .upperPM2_5(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                lowerAlertValue: isOn ? alertService.lowerPM2_5(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            graphDataSource.append(pm25ChartData)
        }

        if vocData.count > 0 {
            let isOn = alertService.isOn(
                type: .voc(lower: 0, upper: 0),
                for: ruuviTag
            )
            let vocChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperVOC(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: vocData,
                lowerAlertValue: isOn ? alertService
                    .lowerVOC(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let vocChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .voc,
                chartData: LineChartData(dataSet: vocChartDataSet),
                upperAlertValue: isOn ? alertService
                    .upperVOC(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                lowerAlertValue: isOn ? alertService.lowerVOC(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            graphDataSource.append(vocChartData)
        }

        if noxData.count > 0 {
            let isOn = alertService.isOn(
                type: .nox(lower: 0, upper: 0),
                for: ruuviTag
            )
            let noxChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperNOX(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: noxData,
                lowerAlertValue: isOn ? alertService
                    .lowerNOX(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let noxChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .nox,
                chartData: LineChartData(dataSet: noxChartDataSet),
                upperAlertValue: isOn ? alertService
                    .upperNOX(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                lowerAlertValue: isOn ? alertService.lowerNOX(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            graphDataSource.append(noxChartData)
        }

        if luminosityData.count > 0 {
            let isOn = alertService.isOn(
                type: .luminosity(lower: 0, upper: 0),
                for: ruuviTag
            )
            let luminosityChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperLuminosity(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: noxData,
                lowerAlertValue: isOn ? alertService
                    .lowerLuminosity(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let luminosityChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .nox,
                chartData: LineChartData(dataSet: luminosityChartDataSet),
                upperAlertValue: isOn ? alertService
                    .upperLuminosity(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                lowerAlertValue: isOn ? alertService.lowerLuminosity(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            graphDataSource.append(luminosityChartData)
        }

        if soundData.count > 0 {
            let isOn = alertService.isOn(
                type: .sound(lower: 0, upper: 0),
                for: ruuviTag
            )
            let soundChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperSound(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: noxData,
                lowerAlertValue: isOn ? alertService
                    .lowerSound(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: flags.showAlertsRangeInGraph
            )
            let soundChartData = NewTagChartEntity(
                ruuviTagId: ruuviTag.id,
                chartType: .nox,
                chartData: LineChartData(dataSet: soundChartDataSet),
                upperAlertValue: isOn ? alertService
                    .upperSound(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                lowerAlertValue: isOn ? alertService.lowerSound(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            graphDataSource.append(soundChartData)
        }

        // Set the initial data for the charts.
        view?.setChartViewData(from: graphDataSource,
                               for: ruuviTag, settings: settings)

        // Update the latest measurement label.
        if let lastMeasurement = graphData.last {
            let sensorSettings = settingsForSensor(ruuviTag)
            view?.updateLatestMeasurement(
                for: ruuviTag,
                temperature: chartEntry(
                    for: lastMeasurement,
                    type: .temperature,
                    sensorSettings: sensorSettings
                ),
                humidity: chartEntry(
                    for: lastMeasurement,
                    type: .humidity,
                    sensorSettings: sensorSettings
                ),
                pressure: chartEntry(
                    for: lastMeasurement,
                    type: .pressure,
                    sensorSettings: sensorSettings
                ),
                aqi: chartEntry(
                    for: lastMeasurement,
                    type: .aqi,
                    sensorSettings: sensorSettings
                ),
                co2: chartEntry(
                    for: lastMeasurement,
                    type: .co2,
                    sensorSettings: sensorSettings
                ),
                pm10: chartEntry(
                    for: lastMeasurement,
                    type: .pm10,
                    sensorSettings: sensorSettings
                ),
                pm25: chartEntry(
                    for: lastMeasurement,
                    type: .pm25,
                    sensorSettings: sensorSettings
                ),
                voc: chartEntry(
                    for: lastMeasurement,
                    type: .voc,
                    sensorSettings: sensorSettings
                ),
                nox: chartEntry(
                    for: lastMeasurement,
                    type: .nox,
                    sensorSettings: sensorSettings
                ),
                luminosity: chartEntry(
                    for: lastMeasurement,
                    type: .luminosity,
                    sensorSettings: sensorSettings
                ),
                sound: chartEntry(
                    for: lastMeasurement,
                    type: .sound,
                    sensorSettings: sensorSettings
                ),
                settings: settings
            )
        }
    }

    // Draw dots is disabled for v1.3.0 onwards until further notice.
    private func drawCirclesIfNeeded(for chartData: LineChartData?, entriesCount: Int? = nil) {
        if let dataSet = chartData?.dataSets.first as? LineChartDataSet {
            let count: Int = if let entriesCount {
                entriesCount
            } else {
                dataSet.entries.count
            }
            switch count {
            case 1:
                dataSet.circleRadius = 6
                dataSet.drawCirclesEnabled = true
            default:
                dataSet.circleRadius = 0.8
                dataSet.drawCirclesEnabled = settings.chartDrawDotsOn
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func chartEntry(
        for data: RuuviMeasurement,
        type: MeasurementType,
        sensorSettings: SensorSettings?
    ) -> ChartDataEntry? {
        var value: Double?
        switch type {
        case .temperature:
            let temp: Temperature?
                // Backword compatibility for the users who used earlier versions than 0.7.7
                // 1: If local record has temperature offset added, calculate and get original temp data
                // 2: Apply current sensor settings
                = if let offset = data.temperatureOffset, offset != 0 {
                data.temperature?
                    .minus(value: offset)?
                    .plus(sensorSettings: sensorSettings)
            } else {
                data.temperature?.plus(sensorSettings: sensorSettings)
            }
            value = measurementService.double(for: temp) ?? 0
        case .humidity:
            let humidity: Humidity?
                // Backword compatibility for the users who used earlier versions than 0.7.7
                // 1: If local record has humidity offset added, calculate and get original humidity data
                // 2: Apply current sensor settings
                = if let offset = data.humidityOffset, offset != 0 {
                data.humidity?
                    .minus(value: offset)?
                    .plus(sensorSettings: sensorSettings)
            } else {
                data.humidity?.plus(sensorSettings: sensorSettings)
            }
            value = measurementService.double(
                for: humidity,
                temperature: data.temperature,
                isDecimal: false
            )
        case .pressure:
            let pressure: Pressure?
                // Backword compatibility for the users who used earlier versions than 0.7.7
                // 1: If local record has pressure offset added, calculate and get original pressure data
                // 2: Apply current sensor settings
                = if let offset = data.pressureOffset, offset != 0 {
                data.pressure?
                    .minus(value: offset)?
                    .plus(sensorSettings: sensorSettings)
            } else {
                data.pressure?.plus(sensorSettings: sensorSettings)
            }
            if let value = measurementService.double(for: pressure) {
                return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
            } else {
                return nil
            }
        case .aqi:
            let (aqi, _, _) = measurementService.aqiString(
                for: data.co2,
                pm25: data.pm2_5,
                voc: data.voc,
                nox: data.nox
            )
            let value = measurementService.double(
                for: Double(aqi)
            )
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)

        case .co2:
            let value = measurementService.double(
                for: data.co2
            )
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)

        case .pm25:
            let value = measurementService.double(
                for: data.pm2_5
            )
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)

        case .pm10:
            let value = measurementService.double(
                for: data.pm10
            )
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)

        case .voc:
            let value = measurementService.double(
                for: data.voc
            )
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)

        case .nox:
            let value = measurementService.double(
                for: data.nox
            )
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)

        case .luminosity:
            let value = measurementService.double(
                for: data.luminosity
            )
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)

        case .sound:
            let value = measurementService.double(
                for: data.sound
            )
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)

        default:
            fatalError("before need implement chart with current type!")
        }
        guard let y = value
        else {
            return nil
        }
        return ChartDataEntry(x: data.date.timeIntervalSince1970, y: y)
    }

    private func settingsForSensor( _ sensor: RuuviTagSensor) -> SensorSettings? {
        if let sensorSettings = sensorSettings
            .first(where: {
                ($0.luid?.any != nil && $0.luid?.any == sensor.luid?.any)
                || ($0.macId?.any != nil && $0.macId?.any == sensor.macId?.any)
            }) {
            return sensorSettings
        }
        return nil
    }
}
// swiftlint:enable file_length
