// swiftlint:disable file_length

import RuuviOntology
import Foundation
import RuuviLocal
import RuuviPresenters
import RuuviService
import BTKit
import RuuviReactor
import CoreBluetooth
import DGCharts
import UIKit

class CardsGraphPresenter: NSObject {
    weak var view: CardsGraphViewInput?
    weak var interactor: TagChartsViewInteractorInput?
    weak var output: CardsGraphPresenterOutput?

    // MARK: Properties
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var snapshot: RuuviTagCardSnapshot?
    private var sensor: AnyRuuviTagSensor?
    private var sensorSettings: SensorSettings?

    // MARK: Dependencies
    private let errorPresenter: ErrorPresenter
    private var settings: RuuviLocalSettings
    private let foreground: BTForeground
    private let ruuviReactor: RuuviReactor
    private let activityPresenter: ActivityPresenter
    private let alertPresenter: AlertPresenter
    private let measurementService: RuuviServiceMeasurement
    private let exportService: RuuviServiceExport
    private let alertService: RuuviServiceAlert
    private let background: BTBackground
    private var flags: RuuviLocalFlags

    // MARK: Observation Tokens
    private var advertisementToken: ObservationToken?
    private var heartbeatToken: ObservationToken?
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

    // MARK: Helper Properties
    private var shouldSyncFromCloud: Bool = true
    private var isSyncing: Bool = false {
        didSet {
            output?.setGraphGattSyncInProgress(isSyncing)
        }
    }
    private var lastSyncSnapshotDate = Date()
    private var lastChartSyncDate = Date()
    private var isBluetoothPermissionGranted: Bool {
        CBCentralManager.authorization == .allowedAlways
    }
    private var datasource: [TagChartViewData] = []
    private var newpoints: [TagChartViewData] = []
    private var chartModules: [MeasurementType] = []
    private var ruuviTagData: [RuuviMeasurement] = []

    // MARK: - Scroll State Management
    private var isUserScrolling: Bool = false
    private var pendingMeasurements: [RuuviMeasurement] = []

    // MARK: Init
    init(
        errorPresenter: ErrorPresenter,
        settings: RuuviLocalSettings,
        foreground: BTForeground,
        ruuviReactor: RuuviReactor,
        activityPresenter: ActivityPresenter,
        alertPresenter: AlertPresenter,
        measurementService: RuuviServiceMeasurement,
        exportService: RuuviServiceExport,
        alertService: RuuviServiceAlert,
        background: BTBackground,
        flags: RuuviLocalFlags
    ) {
        self.errorPresenter = errorPresenter
        self.settings = settings
        self.foreground = foreground
        self.ruuviReactor = ruuviReactor
        self.activityPresenter = activityPresenter
        self.alertPresenter = alertPresenter
        self.measurementService = measurementService
        self.exportService = exportService
        self.alertService = alertService
        self.background = background
        self.flags = flags
        super.init()
    }
}

// MARK: CardsGraphPresenterInput
extension CardsGraphPresenter: CardsGraphPresenterInput {
    func configure(
        with snapshots: [RuuviTagCardSnapshot],
        snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?,
        settings: SensorSettings?
    ) {
        self.snapshots = snapshots
        configure(with: snapshot, sensor: sensor, settings: settings)
        self.interactor?.updateSensorSettings(settings: sensorSettings)
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

    func configure(output: CardsGraphPresenterOutput?) {
        self.output = output
    }

    func start() {
        // Use the one with `shouldSyncFromCloud` since we want to
        // avoid calling cloud sync on demand. For example when graph view is
        // presented from popup we should not call cloud sync as the sync already
        // called once when popup is presented.
    }

    func start(shouldSyncFromCloud: Bool) {
        self.shouldSyncFromCloud = shouldSyncFromCloud
        view?.resetScrollPosition()
        observeLastOpenedChart()
        startListeningToSettings()
        tryToShowSwipeUpHint()
        reloadChartsData(shouldSyncFromCloud: shouldSyncFromCloud)
        stopGattSync()
    }

    func stop() {}

    func scroll(to index: Int, animated: Bool) {
        view?.setActiveSnapshot(snapshot)
        restartObserving()
    }

    func scroll(to measurementType: MeasurementType) {
        view?.scroll(to: measurementType)
    }

    func showAbortSyncConfirmationDialog(
        for snapshot: RuuviTagCardSnapshot,
        from source: GraphHistoryAbortSyncSource
    ) {
        if self.snapshot == snapshot {
            view?.showSyncAbortAlert(source: source)
        }
    }

    func reloadChartsData(shouldSyncFromCloud: Bool) {
        if let sensor {
            interactor?.configure(
                withTag: sensor,
                andSettings: sensorSettings,
                syncFromCloud: shouldSyncFromCloud
            )
        }
        interactor?.restartObservingTags()
    }
}

// MARK: CardsGraphViewOutput
extension CardsGraphPresenter: CardsGraphViewOutput {
    func viewDidLoad() {
        startObservingSensorSettingsChanges()
        startObservingCloudSyncNotification()
    }

    func viewWillAppear() {
        view?.setActiveSnapshot(snapshot)

        view?.historyLengthInHours = settings.chartDurationHours
        view?.showChartStat = settings.chartStatsOn
        view?.compactChartView = settings.compactChartView
        view?.showChartAll = settings.chartShowAll
        view?.showAlertRangeInGraph = settings.showAlertsRangeInGraph
    }

    func viewDidStartScrolling() {
        isUserScrolling = true
    }

    func viewDidEndScrolling() {
        isUserScrolling = false

        // Process all pending measurements
        if !pendingMeasurements.isEmpty {
            let measurementsToProcess = pendingMeasurements
            pendingMeasurements.removeAll()
            insertMeasurements(measurementsToProcess)
        }
    }

    func viewDidTransition() {
        tryToShowSwipeUpHint()
    }

    func viewDidTriggerSync(for snapshot: RuuviTagCardSnapshot?) {
        viewDidStartSync(for: snapshot)

        guard let luid = sensor?.luid, let snapshot = snapshot else { return }
        if !settings.syncDialogHidden(for: luid) {
            view?.showSyncConfirmationDialog(for: snapshot)
        }
    }

    func viewDidTriggerDoNotShowSyncDialog() {
        guard let luid = sensor?.luid else { return }
        settings.setSyncDialogHidden(true, for: luid)
    }

    func viewDidStartSync(for snapshot: RuuviTagCardSnapshot?) {
        guard let snapshot = snapshot else { return }
        // Check bluetooth
        guard foreground.bluetoothState == .poweredOn || !isBluetoothPermissionGranted
        else {
            view?.showBluetoothDisabled(userDeclined: !isBluetoothPermissionGranted)
            return
        }
        isSyncing = true
        let op = interactor?.syncRecords { [weak self] progress in
            DispatchQueue.main.async { [weak self] in
                guard let syncing = self?.isSyncing, syncing
                else {
                    self?.view?.setSync(progress: nil, for: snapshot)
                    return
                }
                self?.view?.setSync(progress: progress, for: snapshot)
            }
        }
        op?.on(success: { [weak self] _ in
            self?.view?.setSync(progress: nil, for: snapshot)
            self?.interactor?.restartObservingData()
        }, failure: { [weak self] _ in
            self?.view?.setSync(progress: nil, for: snapshot)
            self?.view?.showFailedToSyncIn()
        }, completion: { [weak self] in
            self?.view?.setSync(progress: nil, for: snapshot)
            self?.isSyncing = false
        })
    }

    func viewDidTriggerStopSync(for snapshot: RuuviTagCardSnapshot?) {
        view?.showSyncAbortAlert(source: .inPageCancel)
    }

    func viewDidTriggerClear(for snapshot: RuuviTagCardSnapshot?) {
        guard let snapshot else { return }
        view?.showClearConfirmationDialog(for: snapshot)
    }

    func viewDidConfirmToClear(for snapshot: RuuviTagCardSnapshot?) {
        activityPresenter.show(with: .loading(message: nil))
        if let sensor = sensor {
            interactor?.deleteAllRecords(for: sensor)
                .on(failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                }, completion: { [weak self] in
                    self?.activityPresenter.dismiss(immediately: true)
                })
        }
    }

    func viewDidConfirmAbortSync(source: GraphHistoryAbortSyncSource) {
        stopGattSync()
        isSyncing = false

        if let snapshot = snapshot {
            output?.graphGattSyncAborted(for: snapshot, source: source)
        }
    }

    func viewDidTapOnExportCSV() {
        guard let ruuviTag = sensor else { return }
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
        guard let ruuviTag = sensor else { return }
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
        view?.showChartAll = false
        view?.historyLengthInHours = settings.chartDurationHours
    }

    func viewDidSelectAllChartHistory() {
        settings.chartShowAll = true
        settings.chartDurationHours = 240
        view?.showChartAll = settings.chartShowAll
    }

    func viewDidSelectLongerHistory() {
        view?.showLongerHistoryDialog()
    }

    func viewDidSelectTriggerChartStat(show: Bool) {
        settings.chartStatsOn = show
        view?.showChartStat = show
        interactor?.updateChartShowMinMaxAvgSetting(with: show)
    }

    func viewDidSelectTriggerCompactChart(showCompactChartView: Bool) {
        settings.compactChartView = showCompactChartView
        view?.compactChartView = showCompactChartView
    }
}

// MARK: - Private

extension CardsGraphPresenter {
    private func restartObserving() {
        shutDownModule()
        startObservingSensorSettingsChanges()
        startObservingCloudSyncNotification()
        observeLastOpenedChart()
        startListeningToSettings()
        startObservingNetworkSyncNotification(for: sensor)
        tryToShowSwipeUpHint()

        reloadChartsData(shouldSyncFromCloud: shouldSyncFromCloud)
    }

    private func startObservingNetworkSyncNotification(
        for ruuviTag: RuuviTagSensor?
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
                          mac.any == ruuviTag?.macId?.any
                    else {
                        return
                    }
                    switch status {
                    case .complete:
                        self?.interactor?.restartObservingData()
                    default:
                        break
                    }
                }
            )
    }

    private func shutDownModule() {
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
        guard let sensor = sensor else {
            return
        }
        if let lastOpenedChart = settings.lastOpenedChart(),
           lastOpenedChart != sensor.id {
            // Don't clear history automatically
        }
        settings.setLastOpenedChart(with: sensor.id)
    }

    private func tryToShowSwipeUpHint() {
        if UIWindow.isLandscape,
           !settings.tagChartsLandscapeSwipeInstructionWasShown {
            settings.tagChartsLandscapeSwipeInstructionWasShown = true
            view?.showSwipeUpInstruction()
        }
    }

    private func stopGattSync() {
        interactor?.stopSyncRecords()
            .on(success: { [weak self] _ in
                guard self?.view != nil else { return }
                self?.view?.setSyncProgressViewHidden()
            })
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
                self?.interactor?.restartObservingData()
            }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .HumidityUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.interactor?.restartObservingData()
                }
            )
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .PressureUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.interactor?.restartObservingData()
                }
            )
        downsampleDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .DownsampleOnDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.interactor?.restartObservingData()
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
                    sSelf.interactor?.restartObservingData()
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

    private func startObservingSensorSettingsChanges() {
        if let ruuviTag = sensor {
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
                          mac.any == self?.sensor?.macId?.any
                    else {
                        return
                    }
                    if status == .complete {
                        self?.interactor?.restartObservingData()
                    }
                }
            )
    }

    private func reloadChartsWithSensorSettingsChanges() {
        interactor?.restartObservingData()
    }

    private func stopRunningProcesses() {
        interactor?.stopObservingTags()
        interactor?.stopObservingRuuviTagsData()
        stopGattSync()
    }
}

extension CardsGraphPresenter: TagChartsViewInteractorOutput {
    func updateLatestRecord(_ record: RuuviTagSensorRecord) {
        // No op.
    }

    func createChartModules(from: [MeasurementType]) {
        guard view != nil else { return }
        chartModules = from
        view?.createChartViews(from: chartModules)
    }

    func interactorDidError(_ error: RUError) {
        errorPresenter.present(error: error)
    }

    func interactorDidUpdate(sensor: AnyRuuviTagSensor) {
        self.sensor = sensor
        ruuviTagData = interactor?.ruuviTagData ?? []
        createChartData()
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        guard view != nil else { return }

        // If user is scrolling, queue the measurements instead of updating immediately
        if isUserScrolling {
            pendingMeasurements.append(contentsOf: newValues)
            return
        }

        ruuviTagData = interactor?.ruuviTagData ?? []

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
            if let humidityEntry = chartEntry(
                for: measurement,
                type: .anyHumidity
            ) {
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
            if let pm10Entry = chartEntry(for: measurement, type: .pm100) {
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
            updateLatestMeasurement(lastMeasurement)
        }
    }

    private func updateLatestMeasurement(_ measurement: RuuviMeasurement) {
        view?.updateLatestMeasurement(
            temperature: chartEntry(
                for: measurement,
                type: .temperature
            ),
            humidity: chartEntry(
                for: measurement,
                type: .anyHumidity
            ),
            pressure: chartEntry(
                for: measurement,
                type: .pressure
            ),
            aqi: chartEntry(
                for: measurement,
                type: .aqi
            ),
            co2: chartEntry(
                for: measurement,
                type: .co2
            ),
            pm10: chartEntry(
                for: measurement,
                type: .pm100
            ),
            pm25: chartEntry(
                for: measurement,
                type: .pm25
            ),
            voc: chartEntry(
                for: measurement,
                type: .voc
            ),
            nox: chartEntry(
                for: measurement,
                type: .nox
            ),
            luminosity: chartEntry(
                for: measurement,
                type: .luminosity
            ),
            sound: chartEntry(
                for: measurement,
                type: .soundInstant
            ),
            settings: settings
        )
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
            if let humidityEntry = chartEntry(
                for: measurement,
                type: .anyHumidity
            ) {
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
            if let pm10Entry = chartEntry(for: measurement, type: .pm100) {
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
        if temparatureData.count > 0, let ruuviTag = sensor {
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

        if humidityData.count > 0, let ruuviTag = sensor {
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
                chartType: .anyHumidity,
                chartData: LineChartData(dataSet: humidityChartDataSet),
                lowerAlertValue: (isOn && isRelative) ? alertService.lowerRelativeHumidity(
                    for: ruuviTag
                ).map { $0 * 100 } : nil
            )
            datasource.append(humidityChartData)
        }

        if pressureData.count > 0, let ruuviTag = sensor {
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

        if aqiData.count > 0, let ruuviTag = sensor {
            let isOn = alertService.isOn(
                type: .aqi(lower: 0, upper: 0),
                for: ruuviTag
            )
            let aqiChartDataSet = TagChartsHelper.newDataSet(
                upperAlertValue: isOn ? alertService.upperAQI(
                    for: ruuviTag
                ).map {
                    $0
                } : nil,
                entries: aqiData,
                lowerAlertValue: isOn ? alertService
                    .lowerAQI(
                    for: ruuviTag
                ).map { $0 } : nil,
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let aqiChartData = TagChartViewData(
                upperAlertValue: isOn ? alertService
                    .upperAQI(for: ruuviTag)
                    .map {
                    $0
                } : nil,
                chartType: .aqi,
                chartData: LineChartData(dataSet: aqiChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerAQI(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            datasource.append(aqiChartData)
        }

        if co2Data.count > 0, let ruuviTag = sensor {
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

        if pm10Data.count > 0, let ruuviTag = sensor {
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
                chartType: .pm100,
                chartData: LineChartData(dataSet: pm10ChartDataSet),
                lowerAlertValue: isOn ? alertService.lowerPM10(
                    for: ruuviTag
                ).map { $0 } : nil
            )
            datasource.append(pm10ChartData)
        }

        if pm25Data.count > 0, let ruuviTag = sensor {
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

        if vocData.count > 0, let ruuviTag = sensor {
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

        if noxData.count > 0, let ruuviTag = sensor {
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

        if luminosityData.count > 0, let ruuviTag = sensor {
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

        if soundData.count > 0, let ruuviTag = sensor {
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
            updateLatestMeasurement(lastMeasurement)
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

    // swiftlint:disable:next cyclomatic_complexity
    private func chartEntry(for data: RuuviMeasurement, type: MeasurementType) -> ChartDataEntry? {
        var value: Double?

        switch type {
        case .temperature:
            let temp = data.temperature?.plus(sensorSettings: sensorSettings)
            value = measurementService.double(for: temp)
        case .humidity:
            let humidity = data.humidity?.plus(sensorSettings: sensorSettings)
            value = measurementService.double(
                for: humidity,
                temperature: data.temperature,
                isDecimal: false
            )
        case .pressure:
            let pressure = data.pressure?.plus(sensorSettings: sensorSettings)
            value = measurementService.double(for: pressure)
        case .aqi:
            value = measurementService.aqi(for: data.co2, and: data.pm25)
        case .co2:
            value = measurementService.double(for: data.co2)
        case .pm25:
            value = measurementService.double(for: data.pm25)
        case .pm100:
            value = measurementService.double(for: data.pm10)
        case .voc:
            value = measurementService.double(for: data.voc)
        case .nox:
            value = measurementService.double(for: data.nox)
        case .luminosity:
            value = measurementService.double(for: data.luminosity)
        case .soundInstant:
            value = measurementService.double(for: data.soundInstant)
        default:
            fatalError("before need implement chart with current type!")
        }

        // Ensure we have a valid, finite value before creating chart entry
        guard let y = value, y.isFinite else { return nil }

        let x = data.date.timeIntervalSince1970
        guard x.isFinite else { return nil }

        return ChartDataEntry(x: x, y: y)
    }
}
// swiftlint:enable file_length
