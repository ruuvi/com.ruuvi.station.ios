import BTKit
import DGCharts
import CoreBluetooth
import Foundation
import Future
import RuuviLocal
// swiftlint:disable file_length
import RuuviLocalization
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import UIKit

class TagChartViewData: NSObject {
    var chartType: MeasurementType
    var upperAlertValue: Double?
    var chartData: LineChartData?
    var lowerAlertValue: Double?

    init(
        upperAlertValue: Double?,
        chartType: MeasurementType,
        chartData: LineChartData?,
        lowerAlertValue: Double?
    ) {
        self.upperAlertValue = upperAlertValue
        self.chartType = chartType
        self.chartData = chartData
        self.lowerAlertValue = lowerAlertValue
    }
}

class TagChartsViewPresenter: NSObject, TagChartsViewModuleInput {
    weak var view: TagChartsViewInput?

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
    var exportService: RuuviServiceExport!

    var alertService: RuuviServiceAlert!
    var alertHandler: RuuviNotifier!
    var background: BTBackground!

    var feedbackEmail: String!
    var feedbackSubject: String!
    var infoProvider: InfoProvider!

    private var isSyncing: Bool = false

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
    private var historySyncToken: NSObjectProtocol?
    private var downsampleDidChangeToken: NSObjectProtocol?
    private var chartDurationHourDidChangeToken: NSObjectProtocol?
    private var chartDrawDotsDidChangeToken: NSObjectProtocol?
    private var chartShowStatsStateDidChangeToken: NSObjectProtocol?
    private var sensorSettingsToken: RuuviReactorToken?
    private var syncNotificationToken: NSObjectProtocol?
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
            view?.viewModel = viewModel
            view?.historyLengthInHours = settings.chartDurationHours
            view?.showChartStat = settings.chartStatsOn
            view?.compactChartView = settings.compactChartView
            view?.showChartAll = settings.chartShowAll
            view?.showAlertRangeInGraph = settings.showAlertsRangeInGraph
            view?.useNewGraphRendering = settings.useNewGraphRendering
        }
    }

    private var isBluetoothPermissionGranted: Bool {
        CBCentralManager.authorization == .allowedAlways
    }

    var ruuviTagData: [RuuviMeasurement] = []

    private var datasource: [TagChartViewData] = []
    private var newpoints: [TagChartViewData] = []
    private var chartModules: [MeasurementType] = []

    deinit {
        shutDownModule()
    }

    func configure(output: TagChartsViewModuleOutput) {
        self.output = output
    }

    func configure(ruuviTag: AnyRuuviTagSensor) {
        self.ruuviTag = ruuviTag
    }

    func scrollTo(ruuviTag: AnyRuuviTagSensor) {
        if interactor.isSyncingRecords() {
            view?.showSyncAbortAlertForSwipe()
            return
        }

        output?.tagChartSafeToSwipe(to: ruuviTag, module: self)
        self.ruuviTag = ruuviTag
        restartObserving()
    }

    func notifyDismissInstruction(dismissParent: Bool) {
        if interactor.isSyncingRecords() {
            view?.showSyncAbortAlert(dismiss: dismissParent)
        } else {
            output?.tagChartSafeToClose(
                module: self,
                dismissParent: dismissParent
            )
        }
    }

    func dismiss(completion: (() -> Void)? = nil) {
        stopRunningProcesses()
        shutDownModule()
        completion?()
    }
}

extension TagChartsViewPresenter: TagChartsViewOutput {
    func viewDidLoad() {
        startObservingAppState()
        startObservingBackgroundChanges()
        startObservingAlertChanges()
        startObservingDidConnectDisconnectNotifications()
        startObservingLocalNotificationsManager()
        startObservingSensorSettingsChanges()
        startObservingCloudSyncNotification()
    }

    func viewWillAppear() {
        observeLastOpenedChart()
        startObservingRuuviTag()
        startListeningToSettings()
        startObservingBluetoothState()
        startListeningToAlertStatus()
        tryToShowSwipeUpHint()
        interactor
            .configure(
                withTag: ruuviTag,
                andSettings: sensorSettings,
                syncFromCloud: true
            )
        interactor.restartObservingTags()
        stopGattSync()
    }

    func viewWillDisappear() {
        // No op.
    }

    func viewDidTransition() {
        tryToShowSwipeUpHint()
    }

    func viewDidTriggerSync(for viewModel: TagChartsViewModel) {
        viewDidStartSync(for: viewModel)

        guard let luid = ruuviTag.luid else { return }
        if !settings.syncDialogHidden(for: luid) {
            view?.showSyncConfirmationDialog(for: viewModel)
        }
    }

    func viewDidTriggerDoNotShowSyncDialog() {
        guard let luid = ruuviTag.luid else { return }
        settings.setSyncDialogHidden(true, for: luid)
    }

    func viewDidStartSync(for viewModel: TagChartsViewModel) {
        // Check bluetooth
        guard foreground.bluetoothState == .poweredOn || !isBluetoothPermissionGranted
        else {
            view?.showBluetoothDisabled(userDeclined: !isBluetoothPermissionGranted)
            return
        }
        isSyncing = true
        let op = interactor.syncRecords { [weak self] progress in
            DispatchQueue.main.async { [weak self] in
                guard let syncing = self?.isSyncing, syncing
                else {
                    self?.view?.setSync(progress: nil, for: viewModel)
                    return
                }
                self?.view?.setSync(progress: progress, for: viewModel)
            }
        }
        op.on(success: { [weak self] _ in
            self?.view?.setSync(progress: nil, for: viewModel)
            self?.interactor.restartObservingData()
        }, failure: { [weak self] _ in
            self?.view?.setSync(progress: nil, for: viewModel)
            self?.view?.showFailedToSyncIn()
        }, completion: { [weak self] in
            self?.view?.setSync(progress: nil, for: viewModel)
            self?.isSyncing = false
        })
    }

    func viewDidTriggerStopSync(for _: TagChartsViewModel) {
        view?.showSyncAbortAlert(dismiss: false)
    }

    func viewDidTriggerClear(for viewModel: TagChartsViewModel) {
        view?.showClearConfirmationDialog(for: viewModel)
    }

    func viewDidConfirmToClear(for _: TagChartsViewModel) {
        activityPresenter.show(with: .loading(message: nil))
        interactor.deleteAllRecords(for: ruuviTag)
            .on(failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.dismiss(immediately: true)
            })
    }

    func viewDidConfirmAbortSync(dismiss: Bool) {
        if dismiss {
            output?.tagChartSafeToClose(
                module: self,
                dismissParent: dismiss
            )
        } else {
            stopGattSync()
        }
    }

    func viewDidTapOnExportCSV() {
        activityPresenter.show(with: .loading(message: nil))
        exportService.csvLog(
            for: ruuviTag.id,
            version: ruuviTag.version,
            settings: sensorSettings
        )
        .on(success: { [weak self] url in
            self?.view?.showExportSheet(with: url)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.activityPresenter.dismiss(immediately: true)
        })
    }

    func viewDidTapOnExportXLSX() {
        activityPresenter.show(with: .loading(message: nil))
        exportService.xlsxLog(
            for: ruuviTag.id,
            version: ruuviTag.version,
            settings: sensorSettings
        )
        .on(success: { [weak self] url in
            self?.view?.showExportSheet(with: url)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.activityPresenter.dismiss(immediately: true)
        })
    }

    func viewDidSelectChartHistoryLength(hours: Int) {
        settings.chartShowAll = false
        settings.chartDurationHours = hours
    }

    func viewDidSelectAllChartHistory() {
        settings.chartShowAll = true
        settings.chartDurationHours = 240
    }

    func viewDidSelectLongerHistory() {
        view?.showLongerHistoryDialog()
    }

    func viewDidSelectTriggerChartStat(show: Bool) {
        settings.chartStatsOn = show
        view?.showChartStat = show
        interactor.updateChartShowMinMaxAvgSetting(with: show)
    }

    func viewDidSelectTriggerCompactChart(showCompactChartView: Bool) {
        settings.compactChartView = showCompactChartView
        view?.compactChartView = showCompactChartView
    }
}

// MARK: - TagChartsInteractorOutput

extension TagChartsViewPresenter: TagChartsViewInteractorOutput {
    func createChartModules(from: [MeasurementType]) {
        guard view != nil else { return }
        chartModules = from
        view?.createChartViews(from: chartModules)
    }

    func interactorDidError(_ error: RUError) {
        errorPresenter.present(error: error)
    }

    func interactorDidUpdate(sensor: AnyRuuviTagSensor) {
        ruuviTag = sensor
        ruuviTagData = interactor.ruuviTagData
        createChartData()
    }
}

// MARK: - RuuviNotifierObserver

extension TagChartsViewPresenter: RuuviNotifierObserver {
    func ruuvi(notifier _: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        guard uuid == viewModel.uuid.value || uuid == viewModel.mac.value else { return }
        let newValue: AlertState = isTriggered ? .firing : .registered
        if newValue != viewModel.alertState.value {
            viewModel.alertState.value = newValue
        }
    }
}

// MARK: - Private

extension TagChartsViewPresenter {
    private func restartObserving() {
        shutDownModule()
        startObservingBackgroundChanges()
        startObservingAlertChanges()
        startObservingDidConnectDisconnectNotifications()
        startObservingLocalNotificationsManager()
        startObservingSensorSettingsChanges()
        startObservingCloudSyncNotification()
        observeLastOpenedChart()
        startObservingRuuviTag()
        startListeningToSettings()
        startObservingBluetoothState()
        startListeningToAlertStatus()
        startObservingNetworkSyncNotification(for: ruuviTag)
        tryToShowSwipeUpHint()
        interactor
            .configure(
                withTag: ruuviTag,
                andSettings: sensorSettings,
                syncFromCloud: true
            )
        interactor.restartObservingTags()
    }

    private func startObservingAppState() {
        NotificationCenter
            .default
            .addObserver(
                self,
                selector: #selector(reloadChartsData),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
    }

    @objc private func reloadChartsData() {
        interactor
            .configure(
                withTag: ruuviTag,
                andSettings: sensorSettings,
                syncFromCloud: true
            )
        interactor.restartObservingTags()
    }

    private func startObservingNetworkSyncNotification(
        for ruuviTag: RuuviTagSensor
    ) {
        syncNotificationToken?.invalidate()
        syncNotificationToken = nil

        syncNotificationToken = NotificationCenter
            .default
            .addObserver(
                forName: .NetworkSyncHistoryDidChangeStatus,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                          let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                          mac.any == ruuviTag.macId?.any
                    else {
                        return
                    }
                    switch status {
                    case .complete:
                        self?.interactor.restartObservingData()
                    default:
                        break
                    }
                }
            )
    }

    private func shutDownModule() {
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
        historySyncToken?.invalidate()
        downsampleDidChangeToken?.invalidate()
        chartDurationHourDidChangeToken?.invalidate()
        chartShowStatsStateDidChangeToken?.invalidate()
        chartDrawDotsDidChangeToken?.invalidate()
        sensorSettingsToken?.invalidate()
    }

    private func observeLastOpenedChart() {
        guard ruuviTag != nil
        else {
            return
        }
        if let lastOpenedChart = settings.lastOpenedChart(),
           lastOpenedChart != ruuviTag.id {
            view?.clearChartHistory()
        }
        settings.setLastOpenedChart(with: ruuviTag.id)
    }

    private func tryToShowSwipeUpHint() {
        if UIWindow.isLandscape,
           !settings.tagChartsLandscapeSwipeInstructionWasShown {
            settings.tagChartsLandscapeSwipeInstructionWasShown = true
            view?.showSwipeUpInstruction()
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
                guard self?.view != nil else { return }
                self?.view?.setSyncProgressViewHidden()
            })
    }

    private func startObservingRuuviTag() {
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        guard let luid = ruuviTag.luid
        else {
            return
        }
        advertisementToken = foreground.observe(self, uuid: luid.value, closure: { [weak self] _, device in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag, source: .advertisement)
            }
        })

        heartbeatToken = background.observe(self, uuid: luid.value, closure: { [weak self] _, device in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag, source: .heartbeat)
            }
        })
    }

    private func sync(
        device: RuuviTag,
        source: RuuviTagSensorRecordSource
    ) {
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
    }

    // swiftlint:disable:next function_body_length
    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .TemperatureUnitDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.interactor.restartObservingData()
            }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .HumidityUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.interactor.restartObservingData()
                }
            )
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .PressureUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.interactor.restartObservingData()
                }
            )
        downsampleDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .DownsampleOnDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.interactor.restartObservingData()
                }
            )
        chartDurationHourDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .ChartDurationHourDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let sSelf = self else { return }
                    sSelf.interactor.restartObservingData()
                }
            )
        chartShowStatsStateDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .ChartStatsOnDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let sSelf = self else { return }
                    DispatchQueue.main.async {
                        sSelf.view?.showChartStat = sSelf.settings.chartStatsOn
                    }
                }
            )
        chartDrawDotsDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .ChartDrawDotsOnDidChange,
                object: nil,
                queue: .main,
                using: { _ in
                    // TODO: Add this implemention when draw dots is back.
                }
            )
    }

    private func startObservingBackgroundChanges() {
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
        stateToken = foreground.state(self, closure: { [weak self] observer, state in
            guard let sSelf = self else { return }
            if state != .poweredOn || !sSelf.isBluetoothPermissionGranted {
                observer.view?.showBluetoothDisabled(userDeclined: !sSelf.isBluetoothPermissionGranted)
            }
        })
    }

    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviServiceAlertDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
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
                }
            )
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
            .addObserver(
                forName: .BTBackgroundDidConnect,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                       self?.viewModel.uuid.value == uuid {
                        self?.viewModel.isConnected.value = true
                    }
                }
            )

        didDisconnectToken = NotificationCenter
            .default
            .addObserver(
                forName: .BTBackgroundDidDisconnect,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                       self?.viewModel.uuid.value == uuid {
                        self?.viewModel.isConnected.value = false
                    }
                }
            )
    }

    private func startObservingSensorSettingsChanges() {
        sensorSettingsToken = ruuviReactor.observe(ruuviTag) { [weak self] reactorChange in
            guard let self else { return }
            switch reactorChange {
            case let .update(settings):
                self.sensorSettings = settings
                self.reloadChartsWithSensorSettingsChanges()
            case let .insert(sensorSettings):
                self.sensorSettings = sensorSettings
                self.reloadChartsWithSensorSettingsChanges()
            case let .initial(initialSensorSettings):
                self.sensorSettings = initialSensorSettings.first
            case let .error(error):
                self.errorPresenter.present(error: error)
            case .delete:
                self.sensorSettings = nil
                self.reloadChartsWithSensorSettingsChanges()
            }
        }
    }

    private func startObservingLocalNotificationsManager() {
        lnmDidReceiveToken = NotificationCenter
            .default
            .addObserver(
                forName: .LNMDidReceive,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let uuid = notification.userInfo?[LNMDidReceiveKey.uuid] as? String,
                       self?.viewModel.uuid.value != uuid {
                        self?.dismiss()
                    }
                }
            )
    }

    private func startObservingCloudSyncNotification() {
        historySyncToken = NotificationCenter
            .default
            .addObserver(
                forName: .NetworkSyncHistoryDidChangeStatus,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                          let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                          mac.any == self?.ruuviTag.macId?.any
                    else {
                        return
                    }
                    if status == .complete {
                        self?.interactor.restartObservingData()
                    }
                }
            )
    }

    private func reloadChartsWithSensorSettingsChanges() {
        interactor.restartObservingData()
    }

    private func stopRunningProcesses() {
        stopObservingBluetoothState()
        interactor.stopObservingTags()
        interactor.stopObservingRuuviTagsData()
        stopGattSync()
    }
}

extension TagChartsViewPresenter {

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        guard view != nil else { return }
        ruuviTagData = interactor.ruuviTagData

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

            // AQI
            if let aqiEntry = chartEntry(for: measurement, type: .aqi) {
                aqiData.append(aqiEntry)
            }

            // Carbon Dioxide
            if let co2Entry = chartEntry(for: measurement, type: .co2) {
                co2Data.append(co2Entry)
            }

            // PM2.5
            if let pm25Entry = chartEntry(for: measurement, type: .pm25) {
                pm25Data.append(pm25Entry)
            }

            // PM10
            if let pm10Entry = chartEntry(for: measurement, type: .pm10) {
                pm10Data.append(pm10Entry)
            }

            // VOC
            if let vocEntry = chartEntry(for: measurement, type: .voc) {
                vocData.append(vocEntry)
            }

            // NOx
            if let noxEntry = chartEntry(for: measurement, type: .nox) {
                noxData.append(noxEntry)
            }

            // Luminosity
            if let luminosityEntry = chartEntry(
                for: measurement,
                type: .luminosity
            ) {
                luminosityData.append(luminosityEntry)
            }

            // Sound
            if let soundEntry = chartEntry(
                for: measurement,
                type: .soundInstant

            ) {
                soundData.append(soundEntry)
            }
        }

        // Update new measurements on the chart
        view?.updateChartViewData(
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
            isFirstEntry: ruuviTagData.count == 1,
            firstEntry: ruuviTagData.first,
            settings: settings
        )

        // Update the latest measurement label.
        if let lastMeasurement = newValues.last {
            view?.updateLatestMeasurement(
                temperature: chartEntry(
                    for: lastMeasurement,
                    type: .temperature
                ),
                humidity: chartEntry(
                    for: lastMeasurement,
                    type: .humidity
                ),
                pressure: chartEntry(
                    for: lastMeasurement,
                    type: .pressure
                ),
                aqi: chartEntry(
                    for: lastMeasurement,
                    type: .aqi
                ),
                co2: chartEntry(
                    for: lastMeasurement,
                    type: .co2
                ),
                pm10: chartEntry(
                    for: lastMeasurement,
                    type: .pm10
                ),
                pm25: chartEntry(
                    for: lastMeasurement,
                    type: .pm25
                ),
                voc: chartEntry(
                    for: lastMeasurement,
                    type: .voc
                ),
                nox: chartEntry(
                    for: lastMeasurement,
                    type: .nox
                ),
                luminosity: chartEntry(
                    for: lastMeasurement,
                    type: .luminosity
                ),
                sound: chartEntry(
                    for: lastMeasurement,
                    type: .soundInstant
                ),
                settings: settings
            )
        }
    }

    func updateLatestRecord(_ record: RuuviTagSensorRecord) {
        view?.updateLatestRecordStatus(with: record)
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func createChartData() {
        guard view != nil else { return }
        datasource.removeAll()

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

            // AQI
            if let aqiEntry = chartEntry(for: measurement, type: .aqi) {
                aqiData.append(aqiEntry)
            }

            // Carbon Dioxide
            if let co2Entry = chartEntry(for: measurement, type: .co2) {
                co2Data.append(co2Entry)
            }

            // PM2.5
            if let pm25Entry = chartEntry(for: measurement, type: .pm25) {
                pm25Data.append(pm25Entry)
            }

            // PM10
            if let pm10Entry = chartEntry(for: measurement, type: .pm10) {
                pm10Data.append(pm10Entry)
            }

            // VOC
            if let vocEntry = chartEntry(for: measurement, type: .voc) {
                vocData.append(vocEntry)
            }

            // NOx
            if let noxEntry = chartEntry(for: measurement, type: .nox) {
                noxData.append(noxEntry)
            }

            // Luminosity
            if let luminosityEntry = chartEntry(
                for: measurement,
                type: .luminosity
            ) {
                luminosityData.append(luminosityEntry)
            }

            // Sound
            if let soundEntry = chartEntry(
                for: measurement,
                type: .soundInstant
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
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let temperatureChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService.upperCelsius(for: ruuviTag)
                    .flatMap {
                        Temperature($0, unit: .celsius)
                    }.map { measurementService.double(for: $0) } : nil,
                chartType: .temperature,
                chartData: LineChartData(dataSet: temperatureDataSet),
                lowerAlertValue: isOn ? alertService.lowerCelsius(for: ruuviTag)
                    .flatMap {
                        Temperature($0, unit: .celsius)
                    }.map { measurementService.double(for: $0) } : nil
            )
            datasource.append(temperatureChartData)
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
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let humidityChartData = TagChartViewData(
                upperAlertValue: (isOn && isRelative) ? alertService.upperRelativeHumidity(for: ruuviTag).map {
                    $0 * 100
                } : nil,
                chartType: .humidity,
                chartData: LineChartData(dataSet: humidityChartDataSet),
                lowerAlertValue: (isOn && isRelative) ? alertService.lowerRelativeHumidity(
                    for: ruuviTag
                ).map { $0 * 100 } : nil
            )
            datasource.append(humidityChartData)
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
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let pressureChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService.upperPressure(for: ruuviTag)
                    .flatMap {
                        Pressure($0, unit: .hectopascals)
                    }.map { measurementService.double(for: $0) } : nil,
                chartType: .pressure,
                chartData: LineChartData(dataSet: pressureChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerPressure(for: ruuviTag)
                    .flatMap {
                        Pressure($0, unit: .hectopascals)
                    }.map { measurementService.double(for: $0) } : nil
            )
            datasource.append(pressureChartData)
        }

        if aqiData.count > 0 {
            // TODO: Set up AQI Alert and Get Data from here
            let aqiChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: nil,
                entries: aqiData,
                lowerAlertValue: nil,
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let aqiChartData = TagChartViewData(
                upperAlertValue: nil,
                chartType: .aqi,
                chartData: LineChartData(dataSet: aqiChartDataSet),
                lowerAlertValue: nil
            )
            datasource.append(aqiChartData)
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
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let co2ChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService
                    .upperCarbonDioxide(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                chartType: .co2,
                chartData: LineChartData(dataSet: co2ChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerCarbonDioxide(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            datasource.append(co2ChartData)
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
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let pm10ChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService
                    .upperPM10(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                chartType: .pm10,
                chartData: LineChartData(dataSet: pm10ChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerPM10(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            datasource.append(pm10ChartData)
        }

        if pm25Data.count > 0 {
            let isOn = alertService.isOn(
                type: .pMatter25(lower: 0, upper: 0),
                for: ruuviTag
            )
            let pm25ChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperPM25(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: pm25Data,
                lowerAlertValue: isOn ? alertService
                    .lowerPM25(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let pm25ChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService
                    .upperPM25(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                chartType: .pm25,
                chartData: LineChartData(dataSet: pm25ChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerPM25(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            datasource.append(pm25ChartData)
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
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let vocChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService
                    .upperVOC(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                chartType: .voc,
                chartData: LineChartData(dataSet: vocChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerVOC(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            datasource.append(vocChartData)
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
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let noxChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService
                    .upperNOX(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                chartType: .nox,
                chartData: LineChartData(dataSet: noxChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerNOX(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            datasource.append(noxChartData)
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
                entries: luminosityData,
                lowerAlertValue: isOn ? alertService
                    .lowerLuminosity(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let luminosityChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService
                    .upperLuminosity(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                chartType: .luminosity,
                chartData: LineChartData(dataSet: luminosityChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerLuminosity(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            datasource.append(luminosityChartData)
        }

        if soundData.count > 0 {
            let isOn = alertService.isOn(
                type: .soundInstant(lower: 0, upper: 0),
                for: ruuviTag
            )
            let soundChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperSoundInstant(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: soundData,
                lowerAlertValue: isOn ? alertService
                    .lowerSoundInstant(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let soundChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService
                    .upperSoundInstant(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                chartType: .soundInstant,
                chartData: LineChartData(dataSet: soundChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerSoundInstant(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            datasource.append(soundChartData)
        }

        // Set the initial data for the charts.
        view?.setChartViewData(from: datasource, settings: settings)

        // Update the latest measurement label.
        if let lastMeasurement = ruuviTagData.last {
            view?.updateLatestMeasurement(
                temperature: chartEntry(
                    for: lastMeasurement,
                    type: .temperature
                ),
                humidity: chartEntry(
                    for: lastMeasurement,
                    type: .humidity
                ),
                pressure: chartEntry(
                    for: lastMeasurement,
                    type: .pressure
                ),
                aqi: chartEntry(
                    for: lastMeasurement,
                    type: .aqi
                ),
                co2: chartEntry(
                    for: lastMeasurement,
                    type: .co2
                ),
                pm10: chartEntry(
                    for: lastMeasurement,
                    type: .pm10
                ),
                pm25: chartEntry(
                    for: lastMeasurement,
                    type: .pm25
                ),
                voc: chartEntry(
                    for: lastMeasurement,
                    type: .voc
                ),
                nox: chartEntry(
                    for: lastMeasurement,
                    type: .nox
                ),
                luminosity: chartEntry(
                    for: lastMeasurement,
                    type: .luminosity
                ),
                sound: chartEntry(
                    for: lastMeasurement,
                    type: .soundInstant
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
    private func chartEntry(for data: RuuviMeasurement, type: MeasurementType) -> ChartDataEntry? {
        var value: Double?
        switch type {
        case .temperature:
            let temp = data.temperature?.plus(sensorSettings: sensorSettings)
            value = measurementService.double(for: temp) ?? 0
        case .humidity:
            let humidity = data.humidity?.plus(sensorSettings: sensorSettings)
            value = measurementService.double(
                for: humidity,
                temperature: data.temperature,
                isDecimal: false
            )
        case .pressure:
            let pressure = data.pressure?.plus(sensorSettings: sensorSettings)
            if let value = measurementService.double(for: pressure) {
                return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
            } else {
                return nil
            }
        case .aqi:
            let (value, _, _) = measurementService.aqi(
                for: data.co2,
                pm25: data.pm25
            )
            return ChartDataEntry(
                x: data.date.timeIntervalSince1970,
                y: Double(value)
            )

        case .co2:
            let value = measurementService.double(
                for: data.co2
            )
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)

        case .pm25:
            let value = measurementService.double(
                for: data.pm25
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

        case .soundInstant:
            let value = measurementService.double(
                for: data.soundInstant
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
}

// swiftlint:enable file_length
