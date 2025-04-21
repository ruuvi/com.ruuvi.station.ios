// swiftlint:disable file_length
import Combine
import SwiftUI
import RuuviOntology
import RuuviService
import RuuviLocal
import RuuviPresenters
import RuuviReactor
import RuuviNotifier
import BTKit
import RuuviCore
import RuuviStorage
import CoreBluetooth
import RuuviDaemon

// swiftlint:disable:next type_body_length
class CardsCoordinator: ObservableObject {
    // MARK: - Published Properties
    private(set) var transitionHandler: UIViewController?

    // Tab state
    @Published private(set) var activeTab: CardsTabType = .measurement
    @Published private(set) var activeCardViewModel: CardsViewModel?
    @Published private(set) var currentCardIndex: Int = 0

    // Sensor data streams - main shared data
    @Published private(set) var ruuviTags: [AnyRuuviTagSensor] = []
    @Published private(set) var cardViewModels: [CardsViewModel] = []
    @Published private(set) var sensorSettings: [SensorSettings] = []

    // UI State
    @Published var isRefreshing: Bool = false
    @Published var showBluetoothDisabledAlert: Bool = false
    @Published var bluetoothPermissionDeclined: Bool = false

    // MARK: - Dependencies
    private let errorPresenter: ErrorPresenter
    private let settings: RuuviLocalSettings
    private let flags: RuuviLocalFlags
    private let ruuviReactor: RuuviReactor
    private let alertService: RuuviServiceAlert
    private let alertHandler: RuuviNotifier
    private let foreground: BTForeground
    private let background: BTBackground
    private let measurementService: RuuviServiceMeasurement
    private let connectionPersistence: RuuviLocalConnections
    private let featureToggleService: FeatureToggleService
    private let ruuviSensorPropertiesService: RuuviServiceSensorProperties
    private let localSyncState: RuuviLocalSyncState
    private let ruuviStorage: RuuviStorage
    private let permissionPresenter: PermissionPresenter
    private let permissionsManager: RuuviCorePermission

    // MARK: - Private Properties
    private var isBluetoothPermissionGranted: Bool {
        CBCentralManager.authorization == .allowedAlways
    }
    private var mutedTillTimer: Timer?

    // Subscription tokens
    private var ruuviTagToken: RuuviReactorToken?
    private var ruuviTagLatestRecordTokens = [RuuviReactorToken]()
    private var sensorSettingsTokens = [RuuviReactorToken]()
    private var bluetoothPermissionStateToken: ObservationToken?
    private var backgroundImageChangeToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var ruuviTagAdvertisementDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagPropertiesDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagHeartbeatDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagReadLogsOperationFailureToken: NSObjectProtocol?
    private var ruuviTagDidConnectToken: NSObjectProtocol?
    private var ruuviTagDidDisconnectToken: NSObjectProtocol?
    private var cloudModeChangeToken: NSObjectProtocol?
    private var sensorOrderChangeToken: NSObjectProtocol?
    private var ruuviTagLatestDataNetworkSyncToken: NSObjectProtocol?
    private var ruuviTagHistoryNetworkSyncToken: NSObjectProtocol?

    // Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(transitionHandler: UIViewController?) {
        self.transitionHandler = transitionHandler
        self.transitionHandler?.navigationController?.navigationBar.isHidden = true
        self.transitionHandler?.navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        let r = AppAssembly.shared.assembler.resolver
        errorPresenter = r.resolve(ErrorPresenter.self)!
        settings = r.resolve(RuuviLocalSettings.self)!
        flags = r.resolve(RuuviLocalFlags.self)!
        ruuviReactor = r.resolve(RuuviReactor.self)!
        alertService = r.resolve(RuuviServiceAlert.self)!
        alertHandler = r.resolve(RuuviNotifier.self)!
        foreground = r.resolve(BTForeground.self)!
        background = r.resolve(BTBackground.self)!
        measurementService = r.resolve(RuuviServiceMeasurement.self)!
        connectionPersistence = r.resolve(RuuviLocalConnections.self)!
        featureToggleService = r.resolve(FeatureToggleService.self)!
        ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)!
        localSyncState = r.resolve(RuuviLocalSyncState.self)!
        ruuviStorage = r.resolve(RuuviStorage.self)!
        permissionPresenter = r.resolve(PermissionPresenter.self)!
        permissionsManager = r.resolve(RuuviCorePermission.self)!

        setupObservers()
    }

    // MARK: - Public Methods

    func onBackButtonTapped() {
        transitionHandler?.navigationController?.navigationBar.isHidden = false
        transitionHandler?.navigationController?.popViewController(animated: true)
    }

    func onCardSwiped(to index: Int) {
        setActiveCardIndex(index)
    }

    /// Configures the coordinator with initial data
    func configure(
        selectedTab: CardsTabType? = .measurement,
        selectedCard: CardsViewModel?,
        viewModels: [CardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings]
    ) {
        if let selectedTab = selectedTab {
            setActiveTab(selectedTab)
        }

        self.cardViewModels = viewModels
        self.ruuviTags = ruuviTagSensors
        self.sensorSettings = sensorSettings

        // Set initial card index if a card is selected
        if let selectedCard = selectedCard,
           let index = viewModels.firstIndex(where: {
               ($0.luid != nil && $0.luid == selectedCard.luid) ||
               ($0.mac != nil && $0.mac == selectedCard.mac)
           }) {
            self.currentCardIndex = index
            self.activeCardViewModel = selectedCard
        } else if !viewModels.isEmpty {
            self.currentCardIndex = 0
            self.activeCardViewModel = viewModels.first
        }

        // Start observations
        setupObservers()
    }

    /// Sets the active tab and handles tab-specific initialization
    func setActiveTab(_ tab: CardsTabType) {
        activeTab = tab
    }

    /// Sets the active card by index
    func setActiveCardIndex(_ index: Int) {
        guard index >= 0, index < cardViewModels.count else { return }

        currentCardIndex = index
        activeCardViewModel = cardViewModels[index]

        // Update observations for the active card
        restartObservingForActiveCard()
    }

    /// Sets the active card by finding matching LUID or MAC address
    func setActiveCard(byLuid luid: String?, orMac mac: AnyMACIdentifier?) {
        if let index = cardViewModels.firstIndex(where: {
            ($0.luid?.value != nil && $0.luid?.value == luid) ||
            ($0.mac?.value != nil && $0.mac?.value == mac?.value)
        }) {
            currentCardIndex = index
            activeCardViewModel = cardViewModels[index]
            restartObservingForActiveCard()
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        startObservingRuuviTags()
        startObservingBluetoothState()
        startObservingAlertChanges()
        startObservingBackgroundChanges()
        startObservingDaemonsErrors()
        startObservingDidConnectDisconnectNotifications()
        startObservingCloudModeNotification()
        startObservingSensorOrderChanges()
        startObservingNetworkSyncNotifications()
        startMutedTillTimer()
        startListeningLatestRecords()
        observeSensorSettings()
    }

    private func startObservingRuuviTags() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            guard let self = self else { return }

            switch change {
            case let .insert(sensor):
                self.handleSensorInsert(sensor)

            case let .update(sensor):
                self.handleSensorUpdate(sensor)

            case let .delete(sensor):
                self.handleSensorDelete(sensor)

            case let .error(error):
                self.errorPresenter.present(error: error)

            default:
                break
            }
        }
    }

    private func handleSensorInsert(_ sensor: AnyRuuviTagSensor) {
        // Signal daemons to restart for new sensor
        notifyRestartAdvertisementDaemon()
        notifyRestartHeartBeatDaemon()

        // Check firmware version
        checkFirmwareVersion(for: sensor)

        // Add to tags collection
        ruuviTags.append(sensor.any)

        // Create a single new view model for this sensor
        let viewModel = createViewModel(for: sensor)

        // Add to collection and sort
        var updatedViewModels = cardViewModels
        updatedViewModels.append(viewModel)
        cardViewModels = reorder(updatedViewModels)
    }

    private func handleSensorUpdate(_ sensor: AnyRuuviTagSensor) {
        // Find and update the sensor in our collection
        if let index = ruuviTags.firstIndex(where: {
            ($0.macId != nil && $0.macId?.any == sensor.macId?.any) ||
            ($0.luid != nil && $0.luid?.any == sensor.luid?.any)
        }) {
            // Update the sensor in our collection
            ruuviTags[index] = sensor

            // Find and update the corresponding view model
            if let viewModelIndex = cardViewModels.firstIndex(where: {
                ($0.mac != nil && $0.mac == sensor.macId?.any) ||
                ($0.luid != nil && $0.luid == sensor.luid?.any)
            }) {
                // Update only essential properties that come from the sensor itself
                // (not the measurements or settings which are handled separately)
                let viewModel = cardViewModels[viewModelIndex]
                viewModel.update(sensor)

                // If this is the active card, refresh additional properties
                if viewModelIndex == currentCardIndex {
                    restartObservingForActiveCard()
                }
            }
        }
    }

    private func handleSensorDelete(_ sensor: AnyRuuviTagSensor) {
        // Remove from tags collection
        ruuviTags.removeAll(where: { $0.id == sensor.id })

        // Remove from view models
        cardViewModels.removeAll(where: { $0.id == sensor.id })

        // If we deleted the active card, select another one
        if activeCardViewModel?.id == sensor.id {
            if !cardViewModels.isEmpty {
                setActiveCardIndex(min(currentCardIndex, cardViewModels.count - 1))
            } else {
                // No sensors left, handle this case
                activeCardViewModel = nil
                currentCardIndex = 0
                // TODO: Pop to root
            }
        }
    }

    private func createViewModel(for sensor: AnyRuuviTagSensor) -> CardsViewModel {
        let viewModel = CardsViewModel(sensor)

        // Load and set background image
        loadBackgroundImage(for: sensor, viewModel: viewModel)

        // Set connection state
        if let luid = sensor.luid {
            viewModel.isConnected = background.isConnected(uuid: luid.value)
        } else if let macId = sensor.macId {
            viewModel.networkSyncStatus = localSyncState.getSyncStatusLatestRecord(for: macId)
            viewModel.isConnected = false
        }

        // Set alert state
        viewModel.alertState = alertService.hasRegistrations(for: sensor) ? .registered : .empty

        // Set alert bounds
        viewModel.rhAlertLowerBound = alertService.lowerRelativeHumidity(for: sensor)
        viewModel.rhAlertUpperBound = alertService.upperRelativeHumidity(for: sensor)

        // Load latest measurement
        loadLatestMeasurement(for: sensor, viewModel: viewModel)

        // Sync alert configurations
        syncAlerts(for: sensor, viewModel: viewModel)

        return viewModel
    }

    private func loadBackgroundImage(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        ruuviSensorPropertiesService.getImage(for: sensor)
            .on(success: { image in
                viewModel.background = image
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
    }

    private func loadLatestMeasurement(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        ruuviStorage.readLatest(sensor).on { [weak self] record in
            if let record = record {
                let sensorSettings = self?.sensorSettings
                    .first(where: {
                        ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
                            || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
                    })

                viewModel.update(record.with(sensorSettings: sensorSettings))

                // Process alert for this record
                self?.processAlert(record: record, viewModel: viewModel)

                // If this is the active card, refresh UI
                if self?.activeCardViewModel?.id == viewModel.id {
                    self?.objectWillChange.send()
                }
            }
        }
    }

    private func startListeningLatestRecords() {
        // Clear previous tokens
        ruuviTagLatestRecordTokens.forEach { $0.invalidate() }
        ruuviTagLatestRecordTokens.removeAll()

        // Start observing latest records for each sensor
        for viewModel in cardViewModels {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id }) {
                let token = ruuviReactor.observeLatest(ruuviTagSensor) { [weak self] changes in
                    if case let .update(anyRecord) = changes,
                       let record = anyRecord {
                        // Find the correct view model
                        if let viewModel = self?.cardViewModels.first(where: {
                            ($0.luid != nil && ($0.luid == record.luid?.any)) ||
                            ($0.mac != nil && ($0.mac == record.macId?.any))
                        }) {
                            // Get sensor settings
                            let sensorSettings = self?.sensorSettings.first(where: {
                                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid) ||
                                ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
                            })

                            // Apply settings to record
                            let sensorRecord = record.with(sensorSettings: sensorSettings)

                            // Update view model with new data
                            viewModel.update(sensorRecord)

                            // Process alerts
                            self?.processAlert(record: sensorRecord, viewModel: viewModel)

                            // Trigger UI update if this is the active card
                            if self?.activeCardViewModel?.id == viewModel.id {
                                self?.objectWillChange.send()
                            }
                        }
                    }
                }
                ruuviTagLatestRecordTokens.append(token)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func observeSensorSettings() {
        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        for viewModel in cardViewModels {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id }) {
                sensorSettingsTokens.append(
                    ruuviReactor.observe(ruuviTagSensor) { [weak self] change in
                        guard let sSelf = self else { return }
                        switch change {
                        case let .insert(sensorSettings):
                            self?.sensorSettings.append(sensorSettings)
                            if let viewModel = sSelf.cardViewModels.first(where: {
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
                            if let viewModel = sSelf.cardViewModels.first(where: {
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

    private func updateSensorSettings(
        _ updatedSensorSettings: SensorSettings,
        _ ruuviTagSensor: AnyRuuviTagSensor
    ) {
        if let updateIndex = sensorSettings.firstIndex(
            where: { $0.id == updatedSensorSettings.id }
        ) {
            sensorSettings[updateIndex] = updatedSensorSettings
            if let viewModel = cardViewModels.first(where: {
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

    private func startObservingAlertChanges() {
        alertDidChangeToken = NotificationCenter.default.addObserver(
            forName: .RuuviServiceAlertDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                  let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType
            else { return }

            // Find affected view models
            self.cardViewModels.filter {
                ($0.luid != nil && ($0.luid == physicalSensor.luid?.any)) ||
                ($0.mac != nil && ($0.mac == physicalSensor.macId?.any))
            }.forEach { viewModel in
                // Update alert registration state
                if self.alertService.hasRegistrations(for: physicalSensor) {
                    viewModel.alertState = .registered
                } else {
                    viewModel.alertState = .empty
                }

                // Update status for specific alert type
                self.updateIsOnState(of: type, for: physicalSensor.id, viewModel: viewModel)
                self.updateMutedTill(of: type, for: physicalSensor.id, viewModel: viewModel)

                // Trigger UI update if this is the active card
                if self.activeCardViewModel?.id == viewModel.id {
                    self.objectWillChange.send()
                }
            }
        }
    }

    private func startObservingBluetoothState() {
        bluetoothPermissionStateToken = foreground.state(self, closure: { [weak self] _, state in
            guard let self = self else { return }

            if state != .poweredOn || !self.isBluetoothPermissionGranted {
                self.showBluetoothDisabledAlert = true
                self.bluetoothPermissionDeclined = !self.isBluetoothPermissionGranted
            } else {
                self.showBluetoothDisabledAlert = false
            }
        })
    }

    private func startObservingBackgroundChanges() {
        backgroundImageChangeToken = NotificationCenter.default.addObserver(
            forName: .BackgroundPersistenceDidChangeBackground,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier,
                  let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier
            else { return }

            // Find the affected view model
            if let viewModel = self.cardViewModels.first(where: {
                ($0.luid != nil && $0.luid == luid.any) ||
                ($0.mac != nil && $0.mac == macId.any)
            }) {
                if let ruuviTag = self.ruuviTags.first(where: {
                    ($0.luid != nil && $0.luid?.any == luid.any) ||
                    ($0.macId != nil && $0.macId?.any == macId.any)
                }) {
                    // Load the new background image
                    self.loadBackgroundImage(for: ruuviTag, viewModel: viewModel)
                }
            }
        }
    }

    private func startObservingDaemonsErrors() {
        // Observer for advertisement daemon failures
        ruuviTagAdvertisementDaemonFailureToken = NotificationCenter.default.addObserver(
            forName: .RuuviTagAdvertisementDaemonDidFail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let error = userInfo[RuuviTagAdvertisementDaemonDidFailKey.error] as? RUError {
                self?.errorPresenter.present(error: error)
            }
        }

        // Observer for properties daemon failures
        ruuviTagPropertiesDaemonFailureToken = NotificationCenter.default.addObserver(
            forName: .RuuviTagPropertiesDaemonDidFail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let error = userInfo[RuuviTagPropertiesDaemonDidFailKey.error] as? RUError {
                self?.errorPresenter.present(error: error)
            }
        }

        // Observer for heartbeat daemon failures
        ruuviTagHeartbeatDaemonFailureToken = NotificationCenter.default.addObserver(
            forName: .RuuviTagHeartbeatDaemonDidFail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let error = userInfo[RuuviTagHeartbeatDaemonDidFailKey.error] as? RUError {
                self?.errorPresenter.present(error: error)
            }
        }

        // Observer for read logs operation failures
        ruuviTagReadLogsOperationFailureToken = NotificationCenter.default.addObserver(
            forName: .RuuviTagReadLogsOperationDidFail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let error = userInfo[RuuviTagReadLogsOperationDidFailKey.error] as? RUError {
                self?.errorPresenter.present(error: error)
            }
        }
    }

    private func startObservingDidConnectDisconnectNotifications() {
        // Observer for connect events
        ruuviTagDidConnectToken = NotificationCenter.default.addObserver(
            forName: .BTBackgroundDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
               let viewModel = self?.cardViewModels.first(where: { $0.luid == uuid.luid.any }) {
                viewModel.isConnected = true

                // Trigger UI update if this is the active card
                if self?.activeCardViewModel?.id == viewModel.id {
                    self?.objectWillChange.send()
                }
            }
        }

        // Observer for disconnect events
        ruuviTagDidDisconnectToken = NotificationCenter.default.addObserver(
            forName: .BTBackgroundDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
               let viewModel = self?.cardViewModels.first(where: { $0.luid == uuid.luid.any }) {
                viewModel.isConnected = false

                // Trigger UI update if this is the active card
                if self?.activeCardViewModel?.id == viewModel.id {
                    self?.objectWillChange.send()
                }
            }
        }
    }

    private func startObservingCloudModeNotification() {
        cloudModeChangeToken = NotificationCenter.default.addObserver(
            forName: .CloudModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleCloudModeChange()
        }
    }

    private func handleCloudModeChange() {
        // Update connection status for cloud sensors if cloud mode is enabled
        if settings.cloudModeEnabled {
            for viewModel in cardViewModels where viewModel.isCloud {
                viewModel.isConnected = false
            }
            objectWillChange.send()
        }
    }

    private func startObservingSensorOrderChanges() {
        sensorOrderChangeToken = NotificationCenter.default.addObserver(
            forName: .DashboardSensorOrderDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            // Remember current selection
            let currentViewModel = self.activeCardViewModel

            // Reorder view models
            self.cardViewModels = self.reorder(self.cardViewModels)

            // Restore selection
            if let currentViewModel = currentViewModel,
               let index = self.cardViewModels.firstIndex(where: {
                   ($0.luid != nil && $0.luid == currentViewModel.luid) ||
                   ($0.mac != nil && $0.mac == currentViewModel.mac)
               }) {
                self.currentCardIndex = index
            }
        }
    }

    private func startObservingNetworkSyncNotifications() {
        // Latest data sync status changes
        ruuviTagLatestDataNetworkSyncToken = NotificationCenter.default.addObserver(
            forName: .NetworkSyncLatestDataDidChangeStatus,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let mac = userInfo[NetworkSyncStatusKey.mac] as? MACIdentifier,
                  let status = userInfo[NetworkSyncStatusKey.status] as? NetworkSyncStatus
            else { return }

            // Update sync status in view model
            if let viewModel = self.cardViewModels.first(where: { $0.mac == mac.any }) {
                viewModel.networkSyncStatus = status

                // Update UI if this is the active card
                if self.activeCardViewModel?.id == viewModel.id {
                    self.isRefreshing = (status == .syncing)
                    self.objectWillChange.send()
                }
            }
        }

        // History sync status changes
        ruuviTagHistoryNetworkSyncToken = NotificationCenter.default.addObserver(
            forName: .NetworkSyncHistoryDidChangeStatus,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let mac = userInfo[NetworkSyncStatusKey.mac] as? MACIdentifier,
                  let status = userInfo[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                  self.activeTab == .graph
            else { return }

            // Update sync status in view model
            if let viewModel = self.cardViewModels.first(where: { $0.mac == mac.any }) {
                viewModel.networkSyncStatus = status

                // Update UI if this is the active card
                if self.activeCardViewModel?.id == viewModel.id {
                    self.isRefreshing = (status == .syncing)
                    self.objectWillChange.send()
                }
            }
        }
    }

    private func startMutedTillTimer() {
        mutedTillTimer?.invalidate()
        mutedTillTimer = Timer.scheduledTimer(
            withTimeInterval: 5,
            repeats: true
        ) { [weak self] _ in
            self?.reloadMutedTill()
        }
    }

    private func reloadMutedTill() {
//        var didUpdate = false
//
//        // Check and update muted state for all view models
//        for viewModel in cardViewModels {
//            let alertTypes: [(Date?, KeyPath<CardsViewModel, Date?>)] = [
//                (viewModel.temperatureAlertMutedTill, \.temperatureAlertMutedTill),
//                (viewModel.relativeHumidityAlertMutedTill, \.relativeHumidityAlertMutedTill),
//                (viewModel.pressureAlertMutedTill, \.pressureAlertMutedTill),
//                (viewModel.signalAlertMutedTill, \.signalAlertMutedTill),
//                (viewModel.connectionAlertMutedTill, \.connectionAlertMutedTill),
//                (viewModel.movementAlertMutedTill, \.movementAlertMutedTill),
//                // Add other alert types as needed
//            ]
//
//            for (mutedTill, keyPath) in alertTypes {
//                if let mutedTill = mutedTill, mutedTill < Date() {
//                    viewModel[keyPath: keyPath] = nil
//                    didUpdate = true
//                }
//            }
//        }
//
//        // Trigger UI update if needed
//        if didUpdate {
//            objectWillChange.send()
//        }
    }

    private func syncAlerts(for sensor: RuuviTagSensor, viewModel: CardsViewModel) {
        // For each alert type, update the view model
        AlertType.allCases.forEach { type in
            updateIsOnState(of: type, for: sensor.id, viewModel: viewModel)
            updateMutedTill(of: type, for: sensor.id, viewModel: viewModel)
        }

        // Update overall alert state
        updateAlertRegistrations(for: viewModel, sensor: sensor)
    }

    private func updateAlertRegistrations(for viewModel: CardsViewModel? = nil, sensor: PhysicalSensor? = nil) {
        if let viewModel = viewModel, let sensor = sensor {
            // Update a single view model
            if alertService.hasRegistrations(for: sensor) {
                if viewModel.hasAnyFiringAlert() {
                    viewModel.alertState = .firing
                } else {
                    viewModel.alertState = .registered
                }
            } else {
                viewModel.alertState = .empty
            }
        } else {
            // Update all view models
            for viewModel in cardViewModels {
                if let sensor = ruuviTags.first(where: { $0.id == viewModel.id }) {
                    if alertService.hasRegistrations(for: sensor) {
                        if viewModel.hasAnyFiringAlert() {
                            viewModel.alertState = .firing
                        } else {
                            viewModel.alertState = .registered
                        }
                    } else {
                        viewModel.alertState = .empty
                    }
                }
            }
        }

        // Trigger UI update
        objectWillChange.send()
    }

    private func updateIsOnState(of type: AlertType, for uuid: String, viewModel: CardsViewModel) {
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
        case .connection:
            viewModel.isConnectionAlertOn = isOn
        case .movement:
            viewModel.isMovementAlertOn = isOn
        // Add other alert types as needed
        default:
            break
        }
    }

    private func updateMutedTill(of type: AlertType, for uuid: String, viewModel: CardsViewModel) {
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
        case .connection:
            viewModel.connectionAlertMutedTill = date
        case .movement:
            viewModel.movementAlertMutedTill = date
        // Add other alert types as needed
        default:
            break
        }
    }

    private func restartObservingForActiveCard() {
        // Re-initialize observations for active card
        // This ensures we get the latest data for the selected card
        guard let activeCard = activeCardViewModel,
              let sensorId = activeCard.id,
              let sensor = ruuviTags.first(where: { $0.id == sensorId }) else { return }

        // Refresh latest data
        loadLatestMeasurement(for: sensor, viewModel: activeCard)

        // Update alert states
        syncAlerts(for: sensor, viewModel: activeCard)

        // Trigger UI update
        objectWillChange.send()
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

    private func processAlert(record: RuuviTagSensorRecord, viewModel: CardsViewModel) {
        if viewModel.isCloud, let macId = viewModel.mac {
            alertHandler.processNetwork(
                record: record,
                trigger: false,
                for: macId
            )
        } else if let luid = viewModel.luid {
            alertHandler.process(record: record, trigger: false)
        } else if let macId = viewModel.mac {
            alertHandler.processNetwork(record: record, trigger: false, for: macId)
        }
    }

    private func notifyRestartAdvertisementDaemon() {
        NotificationCenter.default.post(
            name: .RuuviTagAdvertisementDaemonShouldRestart,
            object: nil,
            userInfo: nil
        )
    }

    private func notifyRestartHeartBeatDaemon() {
        NotificationCenter.default.post(
            name: .RuuviTagHeartBeatDaemonShouldRestart,
            object: nil,
            userInfo: nil
        )
    }

    private func checkFirmwareVersion(for sensor: RuuviTagSensor) {
        // TODO: Implement firmware version check logic
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Check firmware version logic would go here
        }
    }

    private func removeObservationTokens() {
        ruuviTagToken?.invalidate()
        ruuviTagLatestRecordTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.forEach { $0.invalidate() }
        bluetoothPermissionStateToken?.invalidate()
        backgroundImageChangeToken?.invalidate()
        alertDidChangeToken?.invalidate()
        ruuviTagAdvertisementDaemonFailureToken?.invalidate()
        ruuviTagPropertiesDaemonFailureToken?.invalidate()
        ruuviTagHeartbeatDaemonFailureToken?.invalidate()
        ruuviTagReadLogsOperationFailureToken?.invalidate()
        ruuviTagDidConnectToken?.invalidate()
        ruuviTagDidDisconnectToken?.invalidate()
        cloudModeChangeToken?.invalidate()
        sensorOrderChangeToken?.invalidate()
        ruuviTagLatestDataNetworkSyncToken?.invalidate()
        ruuviTagHistoryNetworkSyncToken?.invalidate()
        mutedTillTimer?.invalidate()
    }

    deinit {
        removeObservationTokens()
    }
}

// MARK: - Publishers

extension CardsCoordinator {
    /// Publisher for all card view models
    var viewModelsData: AnyPublisher<[CardsViewModel], Never> {
        $cardViewModels
            .combineLatest($activeTab)
            .map { sensors, _ in sensors }
            .eraseToAnyPublisher()
    }

    /// Publisher for the current active card index
    var activeCardIndex: AnyPublisher<Int, Never> {
        $currentCardIndex
            .eraseToAnyPublisher()
    }

    /// Publisher for the active card view model
    var activeCardData: AnyPublisher<CardsViewModel?, Never> {
        $cardViewModels
            .combineLatest($currentCardIndex)
            .map { viewModels, index in
                guard !viewModels.isEmpty, index < viewModels.count else { return nil }
                return viewModels[index]
            }
            .eraseToAnyPublisher()
    }

    /// Publisher that emits when the either latest data or history sync is in progress
    var cloudSyncInProgress: AnyPublisher<Bool, Never> {
        $isRefreshing
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Publisher that emits when the active tab changes
    var tabDidChange: AnyPublisher<CardsTabType, Never> {
        $activeTab
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

// MARK: - CardsViewModel Extension

extension CardsViewModel {
    func hasAnyFiringAlert() -> Bool {
        return temperatureAlertState == .firing ||
            relativeHumidityAlertState == .firing ||
            pressureAlertState == .firing ||
            signalAlertState == .firing ||
            connectionAlertState == .firing ||
            movementAlertState == .firing
        // Add other alert types as needed
    }
}

//func showBluetoothDisabled(userDeclined: Bool)
//func showKeepConnectionDialog(for viewModel: CardsViewModel)
//func showFirmwareUpdateDialog(for viewModel: CardsViewModel)
//func showFirmwareDismissConfirmationUpdateDialog(for viewModel: CardsViewModel)

// swiftlint:enable file_length
