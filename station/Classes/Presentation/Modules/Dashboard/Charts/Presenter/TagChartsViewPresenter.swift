// swiftlint:disable file_length
import Foundation
import BTKit
import UIKit
import Charts
import Future
import RuuviOntology
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviNotification
import RuuviNotifier
import RuuviPresenters
import CoreBluetooth

class TagChartViewData: NSObject {
    var chartType: MeasurementType
    var chartData: LineChartData?

    init(chartType: MeasurementType,
         chartData: LineChartData?) {
        self.chartType = chartType
        self.chartData = chartData
    }
}

class TagChartsViewPresenter: NSObject, TagChartsViewModuleInput {

    weak var view: TagChartsViewInput!

    var router: TagChartsViewRouterInput!
    var interactor: TagChartsViewInteractorInput!

    var errorPresenter: ErrorPresenter!
    var settings: RuuviLocalSettings!
    var foreground: BTForeground!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
    var activityPresenter: ActivityPresenter!
    var alertPresenter: AlertPresenter!
    var mailComposerPresenter: MailComposerPresenter!
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!
    var measurementService: RuuviServiceMeasurement!

    var alertService: RuuviServiceAlert!
    var alertHandler: RuuviNotifier!
    var background: BTBackground!

    var feedbackEmail: String!
    var feedbackSubject: String!
    var infoProvider: InfoProvider!

    private var isSyncing: Bool = false
    var isLoading: Bool = false {
        didSet {
            if isLoading {
                activityPresenter.increment()
            } else {
                activityPresenter.decrement()
            }
        }
    }

    private var output: TagChartsViewModuleOutput?
    private var advertisementToken: ObservationToken?
    private var heartbeatToken: ObservationToken?
    private var stateToken: ObservationToken?
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var lnmDidReceiveToken: NSObjectProtocol?
    private var cloudSyncToken: NSObjectProtocol?
    private var downsampleDidChangeToken: NSObjectProtocol?
    private var chartIntervalDidChangeToken: NSObjectProtocol?
    private var chartDurationHourDidChangeToken: NSObjectProtocol?
    private var chartDrawDotsDidChangeToken: NSObjectProtocol?
    private var sensorSettingsToken: RuuviReactorToken?
    private var cloudModeToken: NSObjectProtocol?
    private var lastSyncViewModelDate = Date()
    private var lastChartSyncDate = Date()

    private var ruuviTag: AnyRuuviTagSensor! {
        didSet {
            syncViewModel()
        }
    }

    private var sensorSettings: SensorSettings! {
        didSet {
            interactor.updateSensorSettings(settings: sensorSettings)
        }
    }

    private var viewModel = TagChartsViewModel(type: .ruuvi) {
        didSet {
            self.view.viewModel = self.viewModel
        }
    }

    private var isBluetoothPermissionGranted: Bool {
        if #available(iOS 13.1, *) {
            return CBCentralManager.authorization == .allowedAlways
        } else if #available(iOS 13.0, *) {
            return CBCentralManager().authorization == .allowedAlways
        }
        // Before iOS 13, Bluetooth permissions are not required
        return true
    }

    var ruuviTagData: [RuuviMeasurement] = []

    private var datasource: [TagChartViewData] = []
    private var newpoints: [TagChartViewData] = []
    private var chartModules: [MeasurementType] = []

    deinit {
        stateToken?.invalidate()
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        temperatureUnitToken?.invalidate()
        humidityUnitToken?.invalidate()
        pressureUnitToken?.invalidate()
        backgroundToken?.invalidate()
        alertDidChangeToken?.invalidate()
        didConnectToken?.invalidate()
        didDisconnectToken?.invalidate()
        lnmDidReceiveToken?.invalidate()
        cloudSyncToken?.invalidate()
        downsampleDidChangeToken?.invalidate()
        chartIntervalDidChangeToken?.invalidate()
        chartDurationHourDidChangeToken?.invalidate()
        chartDrawDotsDidChangeToken?.invalidate()
        cloudModeToken?.invalidate()
    }

    func configure(output: TagChartsViewModuleOutput) {
        self.output = output
    }

    func configure(ruuviTag: AnyRuuviTagSensor) {
        self.ruuviTag = ruuviTag
    }

    func dismiss(completion: (() -> Void)? = nil) {
        router.dismiss(completion: completion)
    }
}

extension TagChartsViewPresenter: TagChartsViewOutput {

    func viewDidLoad() {
        startObservingBackgroundChanges()
        startObservingAlertChanges()
        startObservingDidConnectDisconnectNotifications()
        startObservingLocalNotificationsManager()
        startObservingSensorSettingsChanges()
        startObservingCloudSyncNotification()
        startObservingCloudModeNotification()
    }

    func viewWillAppear() {
        observeLastOpenedChart()
        startObservingRuuviTag()
        startListeningToSettings()
        startObservingBluetoothState()
        startListeningToAlertStatus()
        tryToShowSwipeUpHint()
        interactor.configure(withTag: ruuviTag, andSettings: sensorSettings)
        interactor.restartObservingTags()
        handleClearSyncButtons(connectable: false)
        stopGattSync()
    }

    func viewWillDisappear() {
        // Not implemented
    }

    func handleClearSyncButtons(connectable: Bool) {
        view.handleClearSyncButtons(connectable: connectable,
                                    isSyncing: interactor.isSyncingRecords())
    }

    func viewDidTransition() {
        tryToShowSwipeUpHint()
    }

    func viewDidTriggerMenu() {
        router.openMenu(output: self)
    }

    func viewDidTriggerCards(for viewModel: TagChartsViewModel) {
        if interactor.isSyncingRecords() {
            view.showSyncAbortAlert(dismiss: true)
        } else {
            stopRunningProcesses()
            router.dismiss()
        }
    }

    func viewDidTriggerSettings(for viewModel: TagChartsViewModel, scrollToAlert: Bool) {
        if viewModel.type == .ruuvi,
            ruuviTag.luid?.value == viewModel.uuid.value {
            router.openTagSettings(ruuviTag: ruuviTag,
                                   temperature: interactor.lastMeasurement?.temperature,
                                   humidity: interactor.lastMeasurement?.humidity,
                                   rssi: interactor.lastMeasurement?.rssi,
                                   sensor: sensorSettings,
                                   output: self,
                                   scrollToAlert: scrollToAlert)
        } else {
            assert(false)
        }
    }

    func viewDidTriggerSync(for viewModel: TagChartsViewModel) {
        // Check bluetooth
        guard foreground.bluetoothState == .poweredOn || !isBluetoothPermissionGranted  else {
            view.showBluetoothDisabled(userDeclined: !isBluetoothPermissionGranted)
            return
        }
        isSyncing = true
        let connectionTimeout: TimeInterval = settings.connectionTimeout
        let serviceTimeout: TimeInterval = settings.serviceTimeout
        let op = interactor.syncRecords { [weak self] progress in
            DispatchQueue.main.async { [weak self] in
                guard let syncing =  self?.isSyncing, syncing else {
                    return
                }
                self?.view.setSync(progress: progress, for: viewModel)
            }
        }
        op.on(success: { [weak self] _ in
            self?.view.setSync(progress: nil, for: viewModel)
            self?.interactor.restartObservingData()
        }, failure: { [weak self] error in
            self?.view.setSync(progress: nil, for: viewModel)
            if case .btkit(.logic(.connectionTimedOut)) = error {
                self?.view.showFailedToSyncIn(connectionTimeout: connectionTimeout)
            } else if case .ruuviService(.btkit(.logic(.connectionTimedOut))) = error {
                self?.view.showFailedToSyncIn(connectionTimeout: connectionTimeout)
            } else if case .btkit(.logic(.serviceTimedOut)) = error {
                self?.view.showFailedToServeIn(serviceTimeout: serviceTimeout)
            } else {
                self?.errorPresenter.present(error: error)
            }
        }, completion: nil)
    }

    func viewDidTriggerStopSync(for viewModel: TagChartsViewModel) {
        view.showSyncAbortAlert(dismiss: false)
    }

    func viewDidTriggerClear(for viewModel: TagChartsViewModel) {
        view.showClearConfirmationDialog(for: viewModel)
    }

    func viewDidConfirmToClear(for viewModel: TagChartsViewModel) {
        isLoading = true
        interactor.deleteAllRecords(for: ruuviTag)
            .on(failure: {[weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                 self?.isLoading = false
            })
    }

    func viewDidConfirmAbortSync(dismiss: Bool) {
        if dismiss {
            stopRunningProcesses()
            router.dismiss()
        } else {
            stopGattSync()
        }
    }
}
// MARK: - TagChartsInteractorOutput
extension TagChartsViewPresenter: TagChartsViewInteractorOutput {
    func createChartModules(from: [MeasurementType]) {
        chartModules = from
        view.createChartViews(from: chartModules)
    }

    func interactorDidError(_ error: RUError) {
        errorPresenter.present(error: error)
    }

    func interactorDidUpdate(sensor: AnyRuuviTagSensor) {
        ruuviTag = sensor
        ruuviTagData = interactor.ruuviTagData
        self.createChartData()
    }

    func interactorDidSyncComplete(_ recordsCount: Int) {
        let okAction = UIAlertAction(title: "OK".localized(),
                                     style: .default,
                                     handler: nil)
        let title, message: String
        if recordsCount > 0 {
            title = "TagCharts.Status.Success".localized()
            message = String(format: "TagChartsPresenter.NumberOfPointsSynchronizedOverNetwork".localized(),
                             String(recordsCount))
        } else {
            title = "TagChartsPresenter.NetworkSync".localized()
            message = "TagChartsPresenter.NoNewMeasurementsFromNetwork".localized()
        }

        let alertViewModel: AlertViewModel = AlertViewModel(
            title: title,
            message: message,
            style: .alert,
            actions: [okAction])
        alertPresenter.showAlert(alertViewModel)
    }
}

// MARK: - MenuModuleOutput
extension TagChartsViewPresenter: MenuModuleOutput {
    func menu(module: MenuModuleInput, didSelectAddRuuviTag sender: Any?) {
        module.dismiss()
        router.openDiscover()
    }

    func menu(module: MenuModuleInput, didSelectSettings sender: Any?) {
        module.dismiss()
        router.openSettings()
    }

    func menu(module: MenuModuleInput, didSelectAbout sender: Any?) {
        module.dismiss()
        router.openAbout()
    }

    func menu(module: MenuModuleInput, didSelectWhatToMeasure sender: Any?) {
        module.dismiss()
        router.openWhatToMeasurePage()
    }

    func menu(module: MenuModuleInput, didSelectGetMoreSensors sender: Any?) {
        module.dismiss()
        router.openRuuviProductsPage()
    }

    func menu(module: MenuModuleInput, didSelectGetRuuviGateway sender: Any?) {
        module.dismiss()
        router.openRuuviGatewayPage()
    }

    func menu(module: MenuModuleInput, didSelectFeedback sender: Any?) {
        module.dismiss()
        infoProvider.summary { [weak self] summary in
            guard let sSelf = self else { return }
            sSelf.mailComposerPresenter.present(email: sSelf.feedbackEmail,
                                                subject: sSelf.feedbackSubject,
                                                body: "\n\n" + summary)
        }
    }

    func menu(module: MenuModuleInput, didSelectSignIn sender: Any?) {
        module.dismiss()
        router.openSignIn(output: self)
    }

    func menu(module: MenuModuleInput, didSelectOpenConfig sender: Any?) {
        module.dismiss()
    }

    func menu(module: MenuModuleInput, didSelectOpenMyRuuviAccount sender: Any?) {
        module.dismiss()
        router.openMyRuuviAccount()
    }
}

// MARK: - SignInModuleOutput
extension TagChartsViewPresenter: SignInModuleOutput {
    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?) {
        module.dismiss()
    }
}

// MARK: - RuuviNotifierObserver
extension TagChartsViewPresenter: RuuviNotifierObserver {
    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        guard uuid == viewModel.uuid.value || uuid == viewModel.mac.value else { return }
        let newValue: AlertState = isTriggered ? .firing : .registered
        if newValue != viewModel.alertState.value {
            viewModel.alertState.value = newValue
        }
    }
}

// MARK: - TagSettingsModuleOutput
extension TagChartsViewPresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(module: TagSettingsModuleInput,
                                 ruuviTag: RuuviTagSensor) {
        module.dismiss { [weak self] in
            guard let sSelf = self else {
                return
            }
            sSelf.output?.tagChartsDidDeleteTag(module: sSelf)
        }
    }
}

// MARK: - Private
extension TagChartsViewPresenter {
    private func observeLastOpenedChart() {
        guard ruuviTag != nil else {
            return
        }
        if let lastOpenedChart = settings.lastOpenedChart(),
           lastOpenedChart != ruuviTag.id {
            view.clearChartHistory()
        }
        settings.setLastOpenedChart(with: ruuviTag.id)
    }

    private func tryToShowSwipeUpHint() {
        if UIWindow.isLandscape
            && !settings.tagChartsLandscapeSwipeInstructionWasShown {
            settings.tagChartsLandscapeSwipeInstructionWasShown = true
            view.showSwipeUpInstruction()
        }
    }

    private func syncViewModel() {
        let viewModel = TagChartsViewModel(ruuviTag)
        ruuviSensorPropertiesService.getImage(for: ruuviTag)
            .on(success: { image in
                viewModel.background.value = image
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
        if let luid = ruuviTag.luid {
            viewModel.name.value = ruuviTag.name
            viewModel.isConnected.value = background.isConnected(uuid: luid.value)
            // get lastest sensorSettings
            ruuviStorage.readSensorSettings(ruuviTag).on { settings in
                self.sensorSettings = settings
            }
        } else if ruuviTag.macId != nil {
            viewModel.isConnected.value = false
        } else {
            assertionFailure()
        }
        viewModel.alertState.value = alertService.hasRegistrations(for: ruuviTag) ? .registered : .empty
        self.viewModel = viewModel
    }

    private func stopGattSync() {
        interactor.stopSyncRecords()
            .on(success: { [weak self] _ in
                self?.view.setSyncProgressViewHidden()
            })
    }

    private func startObservingRuuviTag() {
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        guard let luid = ruuviTag.luid else {
            return
        }
        advertisementToken = foreground.observe(self, uuid: luid.value, closure: { [weak self] (_, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag, source: .advertisement)
            }
        })

        heartbeatToken = background.observe(self, uuid: luid.value, closure: { [weak self] (_, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag, source: .heartbeat)
            }
        })
    }

    private func sync(device: RuuviTag,
                      source: RuuviTagSensorRecordSource) {
        if device.isConnected {
            if source == .heartbeat {
                if viewModel.isConnectable.value != device.isConnectable {
                    viewModel.isConnectable.value = device.isConnectable
                }
            } else {
                if viewModel.isConnectable.value != device.isConnected {
                    viewModel.isConnectable.value = device.isConnected
                }
            }
        } else {
            if viewModel.isConnectable.value != device.isConnectable {
                viewModel.isConnectable.value = device.isConnectable
            }
        }

        let connectable = viewModel.isConnectable.value.bound &&
                          !settings.cloudModeEnabled
        handleClearSyncButtons(connectable: connectable)
    }

    // swiftlint:disable:next function_body_length
    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
            self?.interactor.restartObservingData()
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.interactor.restartObservingData()
        })
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .PressureUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.interactor.restartObservingData()
        })
        downsampleDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .DownsampleOnDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.interactor.restartObservingData()
        })
        chartIntervalDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .ChartIntervalDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.interactor.restartObservingData()
        })
        chartDurationHourDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .ChartDurationHourDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.interactor.restartObservingData()
        })
        chartDrawDotsDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .ChartDrawDotsOnDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.interactor.restartObservingData()
        })
    }

    private func startObservingBackgroundChanges() {
        backgroundToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidChangeBackground,
                         object: nil,
                         queue: .main) { [weak self] notification in
                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo {
                    let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier
                    if sSelf.viewModel.uuid.value == luid?.value || sSelf.viewModel.mac.value == macId?.value {
                        sSelf.ruuviSensorPropertiesService.getImage(for: sSelf.ruuviTag)
                            .on(success: { [weak sSelf] image in
                                sSelf?.viewModel.background.value = image
                            }, failure: { [weak sSelf] error in
                                sSelf?.errorPresenter.present(error: error)
                            })
                    }
                }
        }
    }

    private func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { (observer, state) in
            if state != .poweredOn || !self.isBluetoothPermissionGranted {
                observer.view.showBluetoothDisabled(userDeclined: !self.isBluetoothPermissionGranted)
            }
        })
    }

    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
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
                self?.viewModel.mac.value == physicalSensor.macId?.value {
                if sSelf.alertService.hasRegistrations(for: physicalSensor) {
                    self?.viewModel.alertState.value = .registered
                } else {
                    self?.viewModel.alertState.value = .empty
                }
            }
        })
    }

    private func startListeningToAlertStatus() {
        if let luid = ruuviTag.luid {
            alertHandler.subscribe(self, to: luid.value)
        } else if let macId = ruuviTag.macId {
            alertHandler.subscribe(self, to: macId.value)
        } else {
            assertionFailure()
        }
    }

    func startObservingDidConnectDisconnectNotifications() {
        didConnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidConnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                                let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                                self?.viewModel.uuid.value == uuid {
                                self?.viewModel.isConnected.value = true
                            }
            })

        didDisconnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidDisconnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                                let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                                self?.viewModel.uuid.value == uuid {
                                self?.viewModel.isConnected.value = false
                            }
            })
    }

    private func startObservingSensorSettingsChanges() {
        sensorSettingsToken = ruuviReactor.observe(ruuviTag, { (reactorChange) in
            switch reactorChange {
            case .update(let settings):
                self.sensorSettings = settings
                self.reloadChartsWithSensorSettingsChanges(with: settings)
            case .insert(let sensorSettings):
                self.sensorSettings = sensorSettings
                self.reloadChartsWithSensorSettingsChanges(with: sensorSettings)
            default: break
            }
        })
    }

    private func startObservingLocalNotificationsManager() {
        lnmDidReceiveToken = NotificationCenter
            .default
            .addObserver(forName: .LNMDidReceive,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let uuid = notification.userInfo?[LNMDidReceiveKey.uuid] as? String ,
                            self?.viewModel.uuid.value != uuid {
                                self?.dismiss()
                            }
            })
    }

    private func startObservingCloudSyncNotification() {
        cloudSyncToken = NotificationCenter
            .default
            .addObserver(forName: .NetworkSyncDidChangeStatus,
                         object: nil,
                         queue: .main,
                         using: { [weak self] notification in
            guard let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                  let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                  status == .complete,
                  mac.any == self?.ruuviTag.macId?.any else {
                return
            }
            self?.interactor.restartObservingData()
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
                guard let sSelf = self else {
                    return
                }
                let connectable = sSelf.viewModel.isConnectable.value.bound &&
                                  !sSelf.settings.cloudModeEnabled
                sSelf.handleClearSyncButtons(connectable: connectable)
            })
    }

    private func reloadChartsWithSensorSettingsChanges(with settings: SensorSettings) {
        interactor.restartObservingData()
    }

    private func stopRunningProcesses() {
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        stopObservingBluetoothState()
        interactor.stopObservingTags()
        interactor.stopObservingRuuviTagsData()
        stopGattSync()
    }
}

extension TagChartsViewPresenter {

    func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        ruuviTagData = interactor.ruuviTagData

        var temparatureData = [ChartDataEntry]()
        var humidityData = [ChartDataEntry]()
        var pressureData = [ChartDataEntry]()

        for measurement in newValues {
            // Temperature
            if let temperatureEntry = chartEntry(for: measurement, type: .temperature) {
                temparatureData.append(temperatureEntry)
            }

            // Humidty
            if let humidityEntry = chartEntry(for: measurement, type: .humidity) {
                humidityData.append(humidityEntry)
            }

            // Pressure
            if let pressureEntry = chartEntry(for: measurement, type: .pressure) {
                pressureData.append(pressureEntry)
            }
        }

        view.updateChartViewData(temperatureEntries: temparatureData,
                                 humidityEntries: humidityData,
                                 pressureEntries: pressureData,
                                 isFirstEntry: ruuviTagData.count == 1,
                                 settings: settings)
    }

    private func createChartData() {

        datasource.removeAll()

        var temparatureData = [ChartDataEntry]()
        var humidityData = [ChartDataEntry]()
        var pressureData = [ChartDataEntry]()

        for measurement in ruuviTagData {
            // Temperature
            if let temperatureEntry = chartEntry(for: measurement, type: .temperature) {
                temparatureData.append(temperatureEntry)
            }

            // Humidty
            if let humidityEntry = chartEntry(for: measurement, type: .humidity) {
                humidityData.append(humidityEntry)
            }

            // Pressure
            if let pressureEntry = chartEntry(for: measurement, type: .pressure) {
                pressureData.append(pressureEntry)
            }
        }

        // Create datasets only if collection has at least one chart entry
        if temparatureData.count > 0 {
            let temperatureDataSet = TagChartsHelper.newDataSet(entries: temparatureData)
            let temperatureChartData = TagChartViewData(chartType: .temperature,
                                                        chartData: LineChartData(dataSet: temperatureDataSet))
            datasource.append(temperatureChartData)
        }

        if humidityData.count > 0 {
            let humidityChartDataSet = TagChartsHelper.newDataSet(entries: humidityData)
            let humidityChartData = TagChartViewData(chartType: .humidity,
                                                        chartData: LineChartData(dataSet: humidityChartDataSet))
            datasource.append(humidityChartData)
        }

        if pressureData.count > 0 {
            let pressureChartDataSet = TagChartsHelper.newDataSet(entries: pressureData)
            let pressureChartData = TagChartViewData(chartType: .pressure,
                                                        chartData: LineChartData(dataSet: pressureChartDataSet))
            datasource.append(pressureChartData)
        }

        view.setChartViewData(from: datasource, settings: settings)
    }

    // Draw dots is disabled for v1.3.0 onwards until further notice.
    private func drawCirclesIfNeeded(for chartData: LineChartData?, entriesCount: Int? = nil) {
        if let dataSet = chartData?.dataSets.first as? LineChartDataSet {
            let count: Int
            if let entriesCount = entriesCount {
                count = entriesCount
            } else {
                count = dataSet.entries.count
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

    private func chartEntry(for data: RuuviMeasurement, type: MeasurementType) -> ChartDataEntry? {
        var value: Double?
        switch type {
        case .temperature:
            var temp: Temperature?
            // Backword compatibility for the users who used earlier versions than 0.7.7
            // 1: If local record has temperature offset added, calculate and get original temp data
            // 2: Apply current sensor settings
            if let offset = data.temperatureOffset, offset != 0 {
                temp = data.temperature?
                    .minus(value: offset)?
                    .plus(sensorSettings: sensorSettings)
            } else {
                temp = data.temperature?.plus(sensorSettings: sensorSettings)
            }
            value = measurementService.double(for: temp) ?? 0
        case .humidity:
            var humidity: Humidity?
            // Backword compatibility for the users who used earlier versions than 0.7.7
            // 1: If local record has humidity offset added, calculate and get original humidity data
            // 2: Apply current sensor settings
            if let offset = data.humidityOffset, offset != 0 {
                humidity = data.humidity?
                    .minus(value: offset)?
                    .plus(sensorSettings: sensorSettings)
            } else {
                humidity = data.humidity?.plus(sensorSettings: sensorSettings)
            }
            value = measurementService.double(for: humidity,
                                                 temperature: data.temperature,
                                              isDecimal: false)
        case .pressure:
            var pressure: Pressure?
            // Backword compatibility for the users who used earlier versions than 0.7.7
            // 1: If local record has pressure offset added, calculate and get original pressure data
            // 2: Apply current sensor settings
            if let offset = data.pressureOffset, offset != 0 {
                pressure = data.pressure?
                    .minus(value: offset)?
                    .plus(sensorSettings: sensorSettings)
            } else {
                pressure = data.pressure?.plus(sensorSettings: sensorSettings)
            }
            if let value = measurementService.double(for: pressure) {
                return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
            } else {
                return nil
            }
        default:
            fatalError("before need implement chart with current type!")
        }
        guard let y = value else {
            return nil
        }
        return ChartDataEntry(x: data.date.timeIntervalSince1970, y: y)
    }
}
// swiftlint:enable file_length
