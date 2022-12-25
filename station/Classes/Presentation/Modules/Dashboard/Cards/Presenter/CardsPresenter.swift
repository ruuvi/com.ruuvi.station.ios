// swiftlint:disable file_length trailing_whitespace
import Foundation
import CoreBluetooth
import BTKit
import RuuviOntology
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviNotification
import RuuviNotifier
import RuuviPresenters
import RuuviDaemon
import RuuviCore

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
    var virtualReactor: VirtualReactor!
    var permissionPresenter: PermissionPresenter!
    var permissionsManager: RuuviCorePermission!

    // MARK: - PRIVATE VARIABLES
    /// Collection of the sensor
    private var ruuviTags = [AnyRuuviTagSensor]()
    /// Collection of virtual sensors
    private var virtualSensors = [AnyVirtualTagSensor]()
    /// Collection of virtual sensors
    private var sensorSettings = [SensorSettings]()
    /// Collection of the card view model.
    private var viewModels = [CardsViewModel]() {
        didSet {
            guard let view = view else { return }
            view.viewModels = viewModels
        }
    }
    /// Card presented currently on the screen.
    private var visibleViewModel: CardsViewModel? {
        didSet {

        }
    }
    /// Equivalent ruuvi tag sensor for visible card on the scree.
    private var visibleRuuviTagSensor: RuuviTagSensor?
    /// Equivalent virtual sensor for visible card on the scree.
    private var visibleVirtualSensor: AnyVirtualTagSensor?
    /// Index for visible card
    private var visibleViewModelIndex: Int = 0 {
        didSet {
            guard let view = view, shouldTriggerScroll else { return }
            view.scrollIndex = visibleViewModelIndex
        }
    }
    /// Sensor settings for the visible sensor.
    private var visibleSensorSettings: SensorSettings?
    /// Whether bluetooth permission is already granted.
    private var isBluetoothPermissionGranted: Bool {
        return CBCentralManager.authorization == .allowedAlways
    }

    /// Should open chart after view is presented.
    private var shouldOpenChart: Bool = false
    private var shouldTriggerScroll: Bool = false
    private weak var tagCharts: TagChartsViewModuleInput?
    private weak var tagChartsModule: UIViewController?
    private weak var output: CardsModuleOutput?
    
    // MARK: - OBSERVERS
    private var ruuviTagToken: RuuviReactorToken?
    private var virtualSensorsToken: VirtualReactorToken?
    private var ruuviTagObserveLastRecordToken: RuuviReactorToken?
    private var virtualSensorsDataToken: VirtualReactorToken?
    private var lnmDidReceiveToken: NSObjectProtocol?
    private var sensorSettingsToken: RuuviReactorToken?
    private var stateToken: ObservationToken?
    private var backgroundToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var webTagDaemonFailureToken: NSObjectProtocol?
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
    func configure(viewModels: [CardsViewModel],
                   ruuviTagSensors: [AnyRuuviTagSensor],
                   virtualSensors: [AnyVirtualTagSensor],
                   sensorSettings: [SensorSettings]
    ) {
        self.viewModels = viewModels
        self.ruuviTags = ruuviTagSensors
        self.virtualSensors = virtualSensors
        self.sensorSettings = sensorSettings
    }

    func configure(output: CardsModuleOutput) {
        self.output = output
    }

    func configure(scrollTo: CardsViewModel?,
                   openChart: Bool) {
        updateVisibleCard(from: scrollTo,
                          openChart: openChart,
                          triggerScroll: true)
    }
}

extension CardsPresenter {
    private func startObservingVisibleTag() {
        observeSensorSettings()
        startListeningLatestRecord()
        startObservingVirtualSensorData()
        startListeningToRuuviTagsAlertStatus()
        startListeningToWebTagsAlertStatus()
        startObservingAlertChanges()
        startObservingLocalNotificationsManager()
        startObservingBackgroundChanges()
        startObservingDaemonsErrors()
        startObservingDidConnectDisconnectNotifications()
        startObservingCloudModeNotification()
    }

    private func updateVisibleCard(from viewModel: CardsViewModel?,
                                   openChart: Bool = false,
                                   triggerScroll: Bool = false) {
        if let index = viewModels.firstIndex(where: {
            $0.id.value == viewModel?.id.value
        }) {
            shouldTriggerScroll = triggerScroll
            visibleViewModelIndex = index
            visibleViewModel = viewModels[index]
            shouldOpenChart = openChart
        }

        if let sensor = ruuviTags
            .first(where: {
                ($0.macId != nil && ($0.macId?.any == viewModel?.mac.value))
            }) {
            visibleRuuviTagSensor = sensor
        }

        if let sensor = virtualSensors
            .first(where: {
                $0.id == viewModel?.id.value
            }) {
            visibleVirtualSensor = sensor
        }

        if let sensorSettings = sensorSettings
            .first(where: {
                ($0.luid != nil && $0.luid?.any == viewModel?.luid.value) ||
                ($0.macId != nil && $0.macId?.any == viewModel?.mac.value)
            }) {
            visibleSensorSettings = sensorSettings
        }

        startObservingVisibleTag()
    }

    private func startObservingWebTags() {
        virtualSensorsToken?.invalidate()
        virtualSensorsToken = virtualReactor.observe { [weak self] change in
            guard let sSelf = self else { return }
            switch change {
            case .delete(let sensor):
                sSelf.virtualSensors.removeAll(where: { $0.id == sensor.id })
                sSelf.syncViewModels()
                if let visible = sSelf.visibleVirtualSensor,
                   visible.id == sensor.id,
                   let first = sSelf.viewModels.first {
                    sSelf.updateVisibleCard(from: first, triggerScroll: true)
                }
            case .update(let sensor):
                if let index = sSelf.virtualSensors
                    .firstIndex(
                        where: {
                            $0.id == sensor.id
                        }) {
                    sSelf.virtualSensors[index] = sensor
                    sSelf.syncViewModels()
                    sSelf.notifyViewModelUpdate()
                }
            case .insert(let sensor):
                sSelf.virtualSensors.append(sensor)
                sSelf.syncViewModels()
                if let viewModel = sSelf.viewModels.first(where: {
                    $0.id.value == sensor.id
                }) {
                    sSelf.updateVisibleCard(from: viewModel,
                                            triggerScroll: true)
                }
            case .error(let error):
                sSelf.errorPresenter.present(error: error)
            default: break
            }
        }
    }

    private func startObservingRuuviTags() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .insert(let sensor):
                sSelf.checkFirmwareVersion(for: sensor)
                sSelf.ruuviTags.append(sensor.any)
                sSelf.syncViewModels()
                if let viewModel = sSelf.viewModels.first(where: {
                    return ($0.luid.value != nil && $0.luid.value == sensor.luid?.any)
                        || ($0.mac.value != nil && $0.mac.value == sensor.macId?.any)
                }) {
                    sSelf.updateVisibleCard(from: viewModel,
                                            triggerScroll: true)
                }
            case .update(let sensor):
                guard let sSelf = self else { return }
                if let index = sSelf.ruuviTags
                    .firstIndex(
                        where: {
                            ($0.macId != nil && $0.macId?.any == sensor.macId?.any)
                            || ($0.luid != nil && $0.luid?.any == sensor.luid?.any)
                        }) {
                    sSelf.ruuviTags[index] = sensor
                    sSelf.syncViewModels()
                    sSelf.notifyViewModelUpdate()
                }

            case .delete(let sensor):
                sSelf.ruuviTags.removeAll(where: { $0.id == sensor.id })
                sSelf.syncViewModels()
                if let visible = sSelf.visibleRuuviTagSensor,
                    visible.any == sensor,
                    let first = sSelf.viewModels.first {
                    sSelf.updateVisibleCard(from: first, triggerScroll: true)
                }
            case .error(let error):
                sSelf.errorPresenter.present(error: error)
            default: break
            }
        }
    }

    private func startListeningLatestRecord() {
        guard let sensor = visibleRuuviTagSensor else {
            return
        }
        ruuviTagObserveLastRecordToken = nil
        ruuviTagObserveLastRecordToken = ruuviReactor.observeLatest(sensor) {
            [weak self] (changes) in

            if case .update(let anyRecord) = changes {
                var isUpdateable: Bool = false

                if let luid = self?.visibleViewModel?.luid,
                    luid.value == anyRecord?.luid?.any {
                    isUpdateable = true
                } else if let macId = self?.visibleViewModel?.mac,
                            macId.value == anyRecord?.macId?.any {
                    isUpdateable = true
                } else {
                    isUpdateable = false
                }

                guard isUpdateable,
                      let viewModel = self?.visibleViewModel,
                      let record = anyRecord else { return }
                let sensorRecord = record.with(sensorSettings:
                                                self?.visibleSensorSettings)
                viewModel.update(sensorRecord)
                self?.view?.applyUpdate(to: viewModel)
                self?.processAlert(record: sensorRecord, viewModel: viewModel)
            }
        }
    }

    private func startObservingVirtualSensorData() {
        guard let virtualSensor = visibleVirtualSensor else {
            return
        }
        virtualSensorsDataToken?.invalidate()
        virtualSensorsDataToken = nil

        virtualSensorsDataToken = virtualReactor.observeLast(virtualSensor, { [weak self] changes in
            if case .update(let anyRecord) = changes,
                let viewModel = self?.visibleViewModel,
                let record = anyRecord {
                let previousDate = viewModel.date.value ?? Date.distantPast
                if previousDate <= record.date {
                    viewModel.update(record)
                    self?.notifyViewModelUpdate()
                }
            }
        })
    }

    private func startListeningToRuuviTagsAlertStatus() {
        if let luid = visibleRuuviTagSensor?.luid {
            alertHandler.subscribe(self, to: luid.value)
        } else if let macId = visibleRuuviTagSensor?.macId {
            alertHandler.subscribe(self, to: macId.value)
        }
    }

    private func startListeningToWebTagsAlertStatus() {
        if let id = visibleVirtualSensor?.id {
            alertHandler.subscribe(self, to: id)
        }
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                if let sSelf = self,
                   let userInfo = notification.userInfo,
                   let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                   let visibleViewModel = sSelf.visibleViewModel,
                   visibleViewModel.mac.value == physicalSensor.macId?.any {
                    if sSelf.alertService.hasRegistrations(for: physicalSensor) {
                        visibleViewModel.alertState.value = .registered
                    } else {
                        visibleViewModel.alertState.value = .empty
                    }
                    sSelf.notifyViewModelUpdate()
                }
        })
    }

    private func startObservingLocalNotificationsManager() {
        lnmDidReceiveToken?.invalidate()
        lnmDidReceiveToken = NotificationCenter
            .default
            .addObserver(
                forName: .LNMDidReceive,
                object: nil,
                queue: .main,
                using: { [weak self] (notification) in
                    if let uuid = notification
                        .userInfo?[LNMDidReceiveKey.uuid] as? String,
                       let index = self?
                        .viewModels
                        .firstIndex(where: { $0.luid.value == uuid.luid.any }),
                       let viewModel = self?
                        .viewModels[index] {
                        self?.view?.scroll(to: index)
                        self?.updateVisibleCard(from: viewModel)
                    }
                }
            )
    }

    private func observeSensorSettings() {
        guard visibleViewModel?.type == .ruuvi,
                let sensor = visibleRuuviTagSensor else { return }
        sensorSettingsToken?.invalidate()
        sensorSettingsToken = ruuviReactor.observe(sensor, { [weak self] change in
            switch change {
            case .insert(let sensorSettings):
                if sensor.luid?.value == sensorSettings.luid?.value ||
                    sensor.macId?.value == sensorSettings.macId?.value {
                    self?.visibleSensorSettings = sensorSettings
                    self?.notifyViewModelUpdate()
                }

            case  .update(let sensorSettings):
                if self?.visibleSensorSettings?.id == sensorSettings.id {
                    self?.visibleSensorSettings = sensorSettings
                    self?.notifyViewModelUpdate()
                }
            case .delete(let deleteSensorSettings):
                if self?.visibleSensorSettings?.id == deleteSensorSettings.id {
                    self?.visibleSensorSettings = nil
                    self?.notifyViewModelUpdate()
                }
            default: break
            }
        })
    }

    private func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { (observer, state) in
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
            .addObserver(forName: .BackgroundPersistenceDidChangeBackground,
                         object: nil,
                         queue: .main) { [weak self] notification in

                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo {
                    let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier

                    let viewModel = sSelf.view?.viewModels
                        .first(where: { $0.luid.value != nil && $0.luid.value == luid?.any })
                        ?? sSelf.view?.viewModels
                        .first(where: { $0.mac.value != nil && $0.mac.value == macId?.any })
                    if let viewModel = viewModel {
                        let ruuviTag = sSelf.ruuviTags
                            .first(where: { $0.luid != nil && $0.luid?.any == luid?.any })
                        ?? sSelf.ruuviTags
                            .first(where: { $0.macId != nil && $0.macId?.any == macId?.any })
                        let webTag = sSelf.virtualSensors.first(where: { $0.id == luid?.value })
                        if let ruuviTag = ruuviTag {
                            sSelf.ruuviSensorPropertiesService.getImage(for: ruuviTag)
                                .on(success: { image in
                                    viewModel.background.value = image
                                    self?.view?.changeCardBackground(of: viewModel, to: image)
                                }, failure: { [weak self] error in
                                    self?.errorPresenter.present(error: error)
                                })
                        }
                        if let webTag = webTag {
                            sSelf.ruuviSensorPropertiesService.getImage(for: webTag)
                                .on(success: { image in
                                    viewModel.background.value = image
                                    self?.view?.changeCardBackground(of: viewModel, to: image)
                                }, failure: { [weak sSelf] error in
                                    sSelf?.errorPresenter.present(error: error)
                                })
                        }
                    }
                }
            }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func startObservingDaemonsErrors() {
        webTagDaemonFailureToken?.invalidate()
        webTagDaemonFailureToken = NotificationCenter
            .default
            .addObserver(forName: .WebTagDaemonDidFail,
                         object: nil,
                         queue: .main) { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let error = userInfo[WebTagDaemonDidFailKey.error] as? RUError {
                    if case .core(let coreError) = error, coreError == .locationPermissionDenied {
                        self?.permissionPresenter.presentNoLocationPermission()
                    } else if case .core(let coreError) = error, coreError == .locationPermissionNotDetermined {
                        self?.permissionsManager.requestLocationPermission { [weak self] (granted) in
                            if !granted {
                                self?.permissionPresenter.presentNoLocationPermission()
                            }
                        }
                    } else if case .virtualService(let serviceError) = error,
                              case .openWeatherMap(let owmError) = serviceError,
                              owmError == OWMError.apiLimitExceeded {
                        self?.view?.showWebTagAPILimitExceededError()
                    } else if case .map(let mapError) = error {
                        let nsError = mapError as NSError
                        if nsError.code == 2, nsError.domain == "kCLErrorDomain" {
                            self?.view?.showReverseGeocodingFailed()
                        } else {
                            self?.errorPresenter.present(error: error)
                        }
                    } else {
                        self?.errorPresenter.present(error: error)
                    }
                }
            }
        ruuviTagAdvertisementDaemonFailureToken?.invalidate()
        ruuviTagAdvertisementDaemonFailureToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviTagAdvertisementDaemonDidFail,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let error = userInfo[RuuviTagAdvertisementDaemonDidFailKey.error] as? RUError {
                                self?.errorPresenter.present(error: error)
                            }
                         })
        ruuviTagPropertiesDaemonFailureToken?.invalidate()
        ruuviTagPropertiesDaemonFailureToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviTagPropertiesDaemonDidFail,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let error = userInfo[RuuviTagPropertiesDaemonDidFailKey.error] as? RUError {
                                self?.errorPresenter.present(error: error)
                            }
                         })
        ruuviTagHeartbeatDaemonFailureToken?.invalidate()
        ruuviTagHeartbeatDaemonFailureToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviTagHeartbeatDaemonDidFail,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let error = userInfo[RuuviTagHeartbeatDaemonDidFailKey.error] as? RUError {
                                self?.errorPresenter.present(error: error)
                            }
                         })
        ruuviTagReadLogsOperationFailureToken?.invalidate()
        ruuviTagReadLogsOperationFailureToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviTagReadLogsOperationDidFail,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let error = userInfo[RuuviTagReadLogsOperationDidFailKey.error] as? RUError {
                                self?.errorPresenter.present(error: error)
                            }
                         })
    }

    func startObservingDidConnectDisconnectNotifications() {
        didConnectToken?.invalidate()
        didConnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidConnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                               let viewModel = self?.viewModels.first(where: { $0.luid.value == uuid.luid.any }) {
                                viewModel.isConnected.value = true
                                self?.view?.applyUpdate(to: viewModel)
                            }
                         })
        didDisconnectToken?.invalidate()
        didDisconnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidDisconnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                               let viewModel = self?.viewModels.first(where: { $0.luid.value == uuid.luid.any }) {
                                viewModel.isConnected.value = false
                                self?.view?.applyUpdate(to: viewModel)
                            }
                         })
    }

    private func startObservingCloudModeNotification() {
        cloudModeToken?.invalidate()
        cloudModeToken = NotificationCenter
            .default
            .addObserver(forName: .CloudModeDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.handleCloudModeState()
            })
    }

    /// The method handles all the operations when cloud mode toggle is turned on/off
    private func handleCloudModeState() {
        // Sync with cloud if cloud mode is turned on
        if settings.cloudModeEnabled {
            for viewModel in viewModels where (viewModel.isCloud.value ?? false) {
                viewModel.isConnected.value = false
                view?.applyUpdate(to: viewModel)
            }
        }
    }

    // ACTIONS
    // swiftlint:disable:next function_body_length
    private func syncViewModels() {
        let ruuviViewModels = ruuviTags.compactMap({ (ruuviTag) -> CardsViewModel in
            let viewModel = CardsViewModel(ruuviTag)
            ruuviSensorPropertiesService.getImage(for: ruuviTag)
                .on(success: {[weak self] image in
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
            let op = ruuviStorage.readLatest(ruuviTag)
            op.on { [weak self] record in
                if let record = record {
                    viewModel.update(record)
                    self?.view?.applyUpdate(to: viewModel)
                    self?.processAlert(record: record, viewModel: viewModel)
                } else {
                    // If the latest data table doesn't have any data by any chance,
                    // Try to get the data from the records table. This is implemented as a safety layer.
                    // This will be removed in future updates
                    self?.ruuviStorage.readLast(ruuviTag).on(success: { record in
                        guard let record = record else {
                            return
                        }
                        viewModel.update(record)
                        self?.view?.applyUpdate(to: viewModel)
                        self?.processAlert(record: record, viewModel: viewModel)
                    })
                }
            }

            return viewModel
        })
        let virtualViewModels = virtualSensors.compactMap({ virtualSensor -> CardsViewModel in
            let viewModel = CardsViewModel(virtualSensor)
            ruuviSensorPropertiesService.getImage(for: virtualSensor)
                .on(success: { [weak self] image in
                    viewModel.background.value = image
                    self?.view?.changeCardBackground(of: viewModel, to: image)
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            viewModel.alertState.value = alertService
                .hasRegistrations(for: virtualSensor) ? .registered : .empty
            viewModel.isConnected.value = false
            view?.applyUpdate(to: viewModel)
            return viewModel
        })

        viewModels = reorder(ruuviViewModels + virtualViewModels)

        guard viewModels.count > 0 else {
            output?.cardsViewDidDismiss(module: self)
            return
        }

        if let viewModel = viewModels.first(where: {
            ($0.luid.value != nil && $0.luid.value == visibleViewModel?.luid.value) ||
            ($0.mac.value != nil && $0.mac.value == visibleViewModel?.mac.value)
        }) {
            updateVisibleCard(from: viewModel, triggerScroll: true)
        }
    }

    private func reorder(_ viewModels: [CardsViewModel]) -> [CardsViewModel] {
        return viewModels.sorted(by: {
            // Sort sensors by name alphabetically
            if let first = $0.name.value?.lowercased(), let second = $1.name.value?.lowercased() {
                return first < second
            } else {
                return true
            }
        })
    }

    private func openTagSettingsScreens(viewModel: CardsViewModel,
                                        scrollToAlert: Bool) {
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
            guard let latestMeasurement = viewModel.latestMeasurement.value else {
                return
            }
            self.router.openTagSettings(
                ruuviTag: ruuviTag,
                latestMeasurement: latestMeasurement,
                sensorSettings: visibleSensorSettings,
                scrollToAlert: scrollToAlert,
                output: self)
        }
    }

    private func showTagCharts() {
        guard shouldOpenChart,
                let visibleViewModel = visibleViewModel else {
            return
        }
        viewDidTriggerShowChart(for: visibleViewModel)
    }

    private func processAlert(record: RuuviTagSensorRecord,
                              viewModel: CardsViewModel) {
        if viewModel.luid.value != nil {
            alertHandler.process(record: record, trigger: false)
        } else {
            guard let macId = viewModel.mac.value else {
                return
            }
            alertHandler.processNetwork(record: record, trigger: false, for: macId)
        }
    }

    private func notifyViewModelUpdate() {
        guard let viewModel = visibleViewModel else { return }
        if let index = viewModels.firstIndex(where: {
            ($0.luid.value != nil && $0.luid.value == viewModel.luid.value) ||
            ($0.mac.value != nil && $0.mac.value == viewModel.mac.value)
        }) {
            viewModels[index] = viewModel
            view?.applyUpdate(to: viewModel)
        }
    }

    private func shutdownModule() {
        ruuviTagToken?.invalidate()
        virtualSensorsToken?.invalidate()
        ruuviTagObserveLastRecordToken?.invalidate()
        virtualSensorsDataToken?.invalidate()
        lnmDidReceiveToken?.invalidate()
        sensorSettingsToken?.invalidate()
        stateToken?.invalidate()
        backgroundToken?.invalidate()
        alertDidChangeToken?.invalidate()
        webTagDaemonFailureToken?.invalidate()
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
        router.dismiss()
    }
}

// MARK: - CardsViewOutput
extension CardsPresenter: CardsViewOutput {
    func viewDidLoad() {
        showTagCharts()
        startObservingRuuviTags()
        startObservingWebTags()
    }
    
    func viewWillAppear() {
        guard viewModels.count > 0 else {
            return
        }
        view?.scroll(to: visibleViewModelIndex,
                    immediately: false,
                    animated: false)
        startObservingBluetoothState()
    }

    func viewDidAppear() {
        // No op.
    }

    func viewWillDisappear() {
        stopObservingBluetoothState()
    }

    func viewDidTriggerSettings(for viewModel: CardsViewModel, with scrollToAlert: Bool) {
        if viewModel.type == .ruuvi {
            if let luid = viewModel.luid.value {
                if settings.keepConnectionDialogWasShown(for: luid)
                    || background.isConnected(uuid: luid.value)
                    || !viewModel.isConnectable.value.bound
                    || !viewModel.isOwner.value.bound
                    || (settings.cloudModeEnabled && viewModel.isCloud.value.bound) {
                    openTagSettingsScreens(viewModel: viewModel, scrollToAlert: scrollToAlert)
                } else {
                    view?.showKeepConnectionDialogSettings(for: viewModel, scrollToAlert: scrollToAlert)
                }
            } else {
                openTagSettingsScreens(viewModel: viewModel, scrollToAlert: scrollToAlert)
            }
        } else if viewModel.type == .web,
                  let webTag = virtualSensors.first(where: { $0.id == viewModel.id.value }) {
            router.openVirtualSensorSettings(
                sensor: webTag,
                temperature: viewModel.temperature.value
            )
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
                        ($0.macId != nil && ($0.macId?.any == viewModel.mac.value))
                    }) {
                    showCharts(for: sensor)
                }
            } else {
                view?.showKeepConnectionDialogChart(for: viewModel)
            }
        } else if viewModel.mac.value != nil {
            if let sensor = ruuviTags
                .first(where: {
                    ($0.macId != nil && ($0.macId?.any == viewModel.mac.value))
                }) {
                showCharts(for: sensor)
            }
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerDismissChart(for viewModel: CardsViewModel,
                                    dismissParent: Bool) {
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
                    ($0.macId != nil && ($0.macId?.any == viewModel.mac.value))
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
                    ($0.macId != nil && ($0.macId?.any == viewModel.mac.value))
                }) {
                showCharts(for: sensor)
            }
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel,
                                                    scrollToAlert: Bool) {
        if let luid = viewModel.luid.value {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel,
                                   scrollToAlert: scrollToAlert)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel,
                                                scrollToAlert: Bool) {
        if let luid = viewModel.luid.value {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel,
                                   scrollToAlert: scrollToAlert)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        guard let luid = viewModel.luid.value,
              let version = viewModel.version.value, version < 5,
              viewModel.isOwner.value.bound,
              featureToggleService.isEnabled(.legacyFirmwareUpdatePopup) else {
            return
        }
        if !settings.firmwareUpdateDialogWasShown(for: luid) {
            view?.showFirmwareUpdateDialog(for: viewModel)
        }
    }

    func viewDidConfirmFirmwareUpdate(for viewModel: CardsViewModel) {
        if let sensor = ruuviTags
            .first(where: {
                ($0.luid != nil && ($0.luid?.any == viewModel.luid.value))
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
    func tagChartSafeToClose(module: TagChartsViewModuleInput,
                             dismissParent: Bool) {
        module.dismiss(completion: { [weak self] in
            if dismissParent {
                self?.viewShouldDismiss()
            } else {
                self?.view?.dismissChart()
            }
        })
    }
}

// MARK: - RuuviNotifierObserver
extension CardsPresenter: RuuviNotifierObserver {
    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        viewModels
            .filter({ $0.luid.value?.value == uuid ||  $0.mac.value?.value == uuid})
            .forEach({ viewModel in
                let newValue: AlertState = isTriggered ? .firing : .registered
                viewModel.alertState.value = newValue
                view?.applyUpdate(to: viewModel)
            })
    }
}

// MARK: - TagSettingsModuleOutput
extension CardsPresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(module: TagSettingsModuleInput,
                                 ruuviTag: RuuviTagSensor) {
        module.dismiss(completion: { [weak self] in
            guard let self = self else { return }
            self.view?.dismissChart()
            self.output?.cardsViewDidRefresh(module: self)
            if let index = self.viewModels.firstIndex(where: {
                ($0.luid.value != nil && $0.luid.value == ruuviTag.luid?.any) ||
                ($0.mac.value != nil && $0.mac.value == ruuviTag.macId?.any)
            }) {
                self.view?.viewModels.remove(at: index)
                if let first = self.viewModels.first {
                    self.updateVisibleCard(from: first, triggerScroll: true)
                }
            }
            
        })
    }

    func tagSettingsDidDismiss(module: TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}

// MARK: - Private
extension CardsPresenter {
    private func showCardSwipeHint() {
        if !settings.cardsSwipeHintWasShown, viewModels.count > 1 {
            view?.showSwipeLeftRightHint()
            settings.cardsSwipeHintWasShown = true
        }
    }

    private func checkFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.interactor.checkAndUpdateFirmwareVersion(for: ruuviTag,
                                                           settings: sSelf.settings)
        }
    }

    private func migrateFirmwareVersion(for ruuviTags: [RuuviTagSensor]) {
        interactor.migrateFWVersionFromDefaults(for: ruuviTags, settings: settings)
    }
}
// swiftlint:enable file_length trailing_whitespace
