// swiftlint:disable file_length

import RuuviOntology
import Humidity
import Foundation
import RuuviLocal
import RuuviPresenters
import RuuviService
import BTKit
import RuuviReactor
import DGCharts
import UIKit

class CardsGraphPresenter: NSObject {
    weak var view: CardsGraphViewInput?
    weak var interactor: CardsGraphViewInteractorInput?
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
    private var datasource: [RuuviGraphViewDataModel] = []
    private var newpoints: [RuuviGraphViewDataModel] = []
    private var chartModules: [MeasurementDisplayVariant] = []
    private var ruuviTagData: [RuuviMeasurement] = []
    private let serviceCoordinatorManager: RuuviTagServiceCoordinatorManager

    // MARK: - Scroll State Management
    private var isUserScrolling: Bool = false
    private var pendingMeasurements: [RuuviMeasurement] = []
    private var pendingScrollRequest: (type: MeasurementType, variant: MeasurementDisplayVariant?)?

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
        flags: RuuviLocalFlags,
        serviceCoordinatorManager: RuuviTagServiceCoordinatorManager = .shared
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
        self.serviceCoordinatorManager = serviceCoordinatorManager
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

    func scroll(
        to measurementType: MeasurementType,
        variant: MeasurementDisplayVariant?
    ) {
        guard !chartModules.isEmpty else {
            pendingScrollRequest = (measurementType, variant)
            return
        }

        guard let targetVariant = resolveVariant(
            for: measurementType,
            preferredVariant: variant
        ) else { return }

        view?.scroll(to: targetVariant)
        pendingScrollRequest = nil
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
        let resolvedState = serviceCoordinatorManager.getCurrentBluetoothState()
        guard resolvedState.isEnabled && !resolvedState.userDeclined else {
            view?.showBluetoothDisabled(userDeclined: resolvedState.userDeclined)
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

extension CardsGraphPresenter: CardsGraphViewInteractorOutput {
    func updateLatestRecord(_ record: RuuviTagSensorRecord) {
        // No op.
    }

    func createChartModules(from: [MeasurementDisplayVariant]) {
        guard view != nil else { return }
        let filtered = filteredVariants(from: from)
        chartModules = filtered.isEmpty ? from : filtered
        view?.createChartViews(from: chartModules)
        if let pending = pendingScrollRequest {
            scroll(to: pending.type, variant: pending.variant)
        }
    }

    func interactorDidError(_ error: RUError) {
        errorPresenter.present(error: error)
    }

    func interactorDidUpdate(sensor: AnyRuuviTagSensor) {
        self.sensor = sensor
        ruuviTagData = interactor?.ruuviTagData ?? []
        createChartData()
    }

    func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        guard view != nil else { return }

        // If user is scrolling, queue the measurements instead of updating immediately
        if isUserScrolling {
            pendingMeasurements.append(contentsOf: newValues)
            return
        }

        ruuviTagData = interactor?.ruuviTagData ?? []

        let entries = collectChartEntries(
            from: newValues,
            variants: chartModules
        )

        view?.updateChartViewData(
            entries,
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
        let latestEntries = chartModules.reduce(
            into: [MeasurementDisplayVariant: ChartDataEntry?]()
        ) {
            result,
            variant in
            result[variant] = chartEntry(
                for: measurement,
                variant: variant
            )
        }

        view?.updateLatestMeasurement(
            latestEntries,
            settings: settings
        )
    }

    private func createChartData() {
        guard view != nil else { return }
        datasource.removeAll()

        let variants = chartModules
        if variants.isEmpty {
            view?.setChartViewData(from: datasource, settings: settings)
            return
        }

        let chartEntries = collectChartEntries(
            from: ruuviTagData,
            variants: variants
        )

        var models: [RuuviGraphViewDataModel] = []

        for variant in variants {
            guard let entries = chartEntries[variant], !entries.isEmpty else {
                continue
            }

            let bounds = alertBounds(for: variant, sensor: sensor)
            let dataSet = RuuviGraphDataSetFactory.newDataSet(
                upperAlertValue: bounds.upper,
                entries: entries,
                lowerAlertValue: bounds.lower,
                showAlertRangeInGraph: settings.showAlertsRangeInGraph
            )
            let model = RuuviGraphViewDataModel(
                upperAlertValue: bounds.upper,
                variant: variant,
                chartData: LineChartData(dataSet: dataSet),
                lowerAlertValue: bounds.lower
            )
            models.append(model)
        }

        datasource = models
        view?.setChartViewData(from: datasource, settings: settings)

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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func chartEntry(
        for data: RuuviMeasurement,
        variant: MeasurementDisplayVariant
    ) -> ChartDataEntry? {
        var value: Double?
        let type = graphMeasurementType(for: variant)

        switch type {
        case .temperature:
            let temp = data.temperature?.plus(sensorSettings: sensorSettings)
            if let temp {
                let targetUnit = variant.resolvedTemperatureUnit(
                    default: settings.temperatureUnit.unitTemperature
                )
                value = temp.converted(to: targetUnit).value
            }
        case .humidity:
            let humidity = data.humidity?.plus(sensorSettings: sensorSettings)
            if let humidity, let temperature = data.temperature {
                let base = Humidity(
                    value: humidity.value,
                    unit: .relative(
                        temperature: temperature
                    )
                )
                switch variant.resolvedHumidityUnit(default: settings.humidityUnit) {
                case .percent:
                    value = base.value * 100
                case .gm3:
                    value = base.converted(to: .absolute).value
                case .dew:
                    if let dew = try? base.dewPoint(temperature: temperature) {
                        let targetUnit = variant.resolvedTemperatureUnit(
                            default: settings.temperatureUnit.unitTemperature
                        )
                        value = dew.converted(to: targetUnit).value
                    }
                }
            }
        case .pressure:
            let pressure = data.pressure?.plus(sensorSettings: sensorSettings)
            if let pressure {
                let targetUnit = variant.resolvedPressureUnit(default: settings.pressureUnit)
                value = pressure.converted(to: targetUnit).value
            }
        case .aqi:
            value = measurementService.aqi(for: data.co2, and: data.pm25)
        case .co2:
            value = measurementService.double(for: data.co2)
        case .pm10:
            value = measurementService.double(for: data.pm1)
        case .pm25:
            value = measurementService.double(for: data.pm25)
        case .pm40:
            value = measurementService.double(for: data.pm4)
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
        case .soundPeak:
            value = measurementService.double(for: data.soundPeak)
        case .soundAverage:
            value = measurementService.double(for: data.soundAvg)
        case .voltage:
            value = measurementService.double(for: data.voltage)
        case .rssi:
            value = data.rssi.map(Double.init)
        case .accelerationX:
            value = data.acceleration?.x.converted(to: .gravity).value
        case .accelerationY:
            value = data.acceleration?.y.converted(to: .gravity).value
        case .accelerationZ:
            value = data.acceleration?.z.converted(to: .gravity).value
        default:
            fatalError("Unhandled chart type \(type)")
        }

        // Ensure we have a valid, finite value before creating chart entry
        guard let y = value, y.isFinite else { return nil }

        let x = data.date.timeIntervalSince1970
        guard x.isFinite else { return nil }

        return ChartDataEntry(x: x, y: y)
    }

    private func collectChartEntries(
        from measurements: [RuuviMeasurement],
        variants: [MeasurementDisplayVariant]
    ) -> [MeasurementDisplayVariant: [ChartDataEntry]] {
        var result: [MeasurementDisplayVariant: [ChartDataEntry]] = [:]

        for measurement in measurements {
            for variant in variants {
                guard let entry = chartEntry(
                    for: measurement,
                    variant: variant
                ) else {
                    continue
                }
                result[variant, default: []].append(entry)
            }
        }

        return result
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func alertBounds(
        for variant: MeasurementDisplayVariant,
        sensor: AnyRuuviTagSensor?
    ) -> (lower: Double?, upper: Double?) {
        guard
            let sensor,
            let alertType = variant.type.toAlertType(),
            alertService.isOn(type: alertType, for: sensor)
        else {
            return (nil, nil)
        }

        let type = graphMeasurementType(for: variant)

        switch type {
        case .temperature:
            let upper = alertService.upperCelsius(for: sensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map {
                    $0.converted(
                        to: variant.resolvedTemperatureUnit(default: settings.temperatureUnit.unitTemperature)
                    ).value
                }
            let lower = alertService.lowerCelsius(for: sensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map {
                    $0.converted(
                        to: variant.resolvedTemperatureUnit(default: settings.temperatureUnit.unitTemperature)
                    ).value
                }
            return (lower, upper)
        case .humidity:
            guard variant.resolvedHumidityUnit(default: settings.humidityUnit) == .percent else {
                return (nil, nil)
            }
            let upper = alertService.upperRelativeHumidity(for: sensor).map { $0 * 100 }
            let lower = alertService.lowerRelativeHumidity(for: sensor).map { $0 * 100 }
            return (lower, upper)
        case .pressure:
            let upper = alertService.upperPressure(for: sensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map {
                    $0.converted(
                        to: variant.resolvedPressureUnit(default: settings.pressureUnit)
                    ).value
                }
            let lower = alertService.lowerPressure(for: sensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map {
                    $0.converted(
                        to: variant.resolvedPressureUnit(default: settings.pressureUnit)
                    ).value
                }
            return (lower, upper)
        case .aqi:
            return (
                alertService.lowerAQI(for: sensor),
                alertService.upperAQI(for: sensor)
            )
        case .co2:
            return (
                alertService.lowerCarbonDioxide(for: sensor),
                alertService.upperCarbonDioxide(for: sensor)
            )
        case .pm10:
            return (
                alertService.lowerPM1(for: sensor),
                alertService.upperPM1(for: sensor)
            )
        case .pm25:
            return (
                alertService.lowerPM25(for: sensor),
                alertService.upperPM25(for: sensor)
            )
        case .pm40:
            return (
                alertService.lowerPM4(for: sensor),
                alertService.upperPM4(for: sensor)
            )
        case .pm100:
            return (
                alertService.lowerPM10(for: sensor),
                alertService.upperPM10(for: sensor)
            )
        case .voc:
            return (
                alertService.lowerVOC(for: sensor),
                alertService.upperVOC(for: sensor)
            )
        case .nox:
            return (
                alertService.lowerNOX(for: sensor),
                alertService.upperNOX(for: sensor)
            )
        case .luminosity:
            return (
                alertService.lowerLuminosity(for: sensor),
                alertService.upperLuminosity(for: sensor)
            )
        case .soundInstant:
            return (
                alertService.lowerSoundInstant(for: sensor),
                alertService.upperSoundInstant(for: sensor)
            )
        case .soundPeak:
            return (
                alertService.lowerSoundPeak(for: sensor),
                alertService.upperSoundPeak(for: sensor)
            )
        case .soundAverage:
            return (
                alertService.lowerSoundAverage(for: sensor),
                alertService.upperSoundAverage(for: sensor)
            )
        case .rssi:
            return (
                alertService.lowerSignal(for: sensor),
                alertService.upperSignal(for: sensor)
            )
        default:
            return (nil, nil)
        }
    }

    private func resolveVariant(
        for measurementType: MeasurementType,
        preferredVariant: MeasurementDisplayVariant?
    ) -> MeasurementDisplayVariant? {
        if let preferred = preferredVariant,
           chartModules.contains(preferred) {
            return preferred
        }

        switch measurementType {
        case .humidity:
            return chartModules.first { $0.type.isSameCase(as: measurementType) }
        default:
            return chartModules.first { $0.type.isSameCase(as: measurementType) }
        }
    }

    private func graphMeasurementType(
        for variant: MeasurementDisplayVariant
    ) -> MeasurementType {
        if variant.type.isSameCase(as: .humidity) {
            return .humidity
        }
        return variant.type
    }

    private func filteredVariants(
        from modules: [MeasurementDisplayVariant]
    ) -> [MeasurementDisplayVariant] {
        guard let visibility = snapshot?.metadata.measurementVisibility else {
            return modules
        }
        return modules.filter { variant in
            visibility.visibleVariants.contains(where: { $0 == variant })
        }
    }
}
// swiftlint:enable file_length
