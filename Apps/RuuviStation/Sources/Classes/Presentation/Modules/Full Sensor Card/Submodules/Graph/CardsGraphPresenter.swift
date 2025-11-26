// swiftlint:disable file_length

import RuuviOntology
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
    private struct CachedChartData {
        let modules: [MeasurementDisplayVariant]
        let measurements: [RuuviMeasurement]
        let entries: [MeasurementDisplayVariant: [ChartDataEntrySnapshot]]
    }
    private var chartCache: [String: CachedChartData] = [:]
    private var chartCacheOrder: [String] = []
    private let chartCacheLimit = 5
    private let chartComputationQueue = DispatchQueue(
        label: "com.ruuvi.cardsgraph.chartbuilder",
        qos: .userInitiated
    )
    private var chartDataGeneration: Int = 0
    private var currentFingerprint: MeasurementFingerprint?
    private lazy var variantResolver = MeasurementVariantResolver(
        settings: settings,
        measurementService: measurementService,
        alertService: alertService
    )

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
        let previousId = self.snapshot?.id
        self.snapshot = snapshot
        self.sensor = sensor
        self.sensorSettings = settings
        handleSnapshotChangeIfNeeded(previousSnapshotId: previousId, newSnapshot: snapshot)
        applyVisibilityChangeIfNeeded()
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
    private func handleSnapshotChangeIfNeeded(
        previousSnapshotId: String?,
        newSnapshot: RuuviTagCardSnapshot
    ) {
        guard previousSnapshotId != newSnapshot.id else { return }
        pendingMeasurements.removeAll()
        newpoints.removeAll()

        if !applyCachedChartIfAvailable(for: newSnapshot) {
            clearChartStateForNewSensor()
        }
    }

    private func applyCachedChartIfAvailable(
        for snapshot: RuuviTagCardSnapshot
    ) -> Bool {
        guard
            let cached = chartCache[snapshot.id],
            !cached.modules.isEmpty
        else {
            return false
        }

        chartModules = cached.modules
        ruuviTagData = cached.measurements
        let restoredEntries = cached.entries.mapValues { $0.map { $0.toEntry() } }
        let models = buildChartModels(
            for: chartModules,
            entries: restoredEntries,
            sensor: sensor
        )
        datasource = models
        view?.createChartViews(from: chartModules)
        view?.setChartViewData(from: models, settings: settings)
        if let lastMeasurement = ruuviTagData.last {
            updateLatestMeasurement(lastMeasurement)
        }
        currentFingerprint = MeasurementFingerprint(measurements: ruuviTagData)
        return true
    }

    private func clearChartStateForNewSensor() {
        chartModules.removeAll()
        ruuviTagData.removeAll()
        datasource.removeAll()
        view?.clearChartHistory()
        invalidatePendingChartComputation()
        currentFingerprint = nil
    }

    private func cacheCurrentChartData(
        entries: [MeasurementDisplayVariant: [ChartDataEntry]],
        measurements: [RuuviMeasurement]
    ) {
        guard let key = snapshot?.id else { return }
        let snapshots = entries.mapValues { $0.map { ChartDataEntrySnapshot(entry: $0) } }
        let cached = CachedChartData(
            modules: chartModules,
            measurements: measurements,
            entries: snapshots
        )
        chartCache[key] = cached
        updateCacheOrder(for: key)
        currentFingerprint = MeasurementFingerprint(measurements: measurements)
    }

    private func updateCacheOrder(for key: String) {
        chartCacheOrder.removeAll { $0 == key }
        chartCacheOrder.append(key)
        if chartCacheOrder.count > chartCacheLimit,
           let removed = chartCacheOrder.first {
            chartCacheOrder.removeFirst()
            chartCache.removeValue(forKey: removed)
        }
    }

    private func nextChartDataGeneration() -> Int {
        chartDataGeneration &+= 1
        return chartDataGeneration
    }

    private func invalidatePendingChartComputation() {
        chartDataGeneration &+= 1
    }

    private struct MeasurementFingerprint: Equatable {
        let count: Int
        let firstDate: Date?
        let lastDate: Date?

        init(measurements: [RuuviMeasurement]) {
            count = measurements.count
            firstDate = measurements.first?.date
            lastDate = measurements.last?.date
        }
    }

    private struct ChartDataEntrySnapshot {
        let x: Double
        let y: Double

        init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }

        init(entry: ChartDataEntry) {
            self.init(x: entry.x, y: entry.y)
        }

        func toEntry() -> ChartDataEntry {
            ChartDataEntry(x: x, y: y)
        }
    }

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
        let newMeasurements = interactor?.ruuviTagData ?? []
        let newFingerprint = MeasurementFingerprint(measurements: newMeasurements)
        ruuviTagData = newMeasurements
        if newFingerprint == currentFingerprint {
            return
        }
        rebuildChartData(updateView: true)
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
        rebuildChartData(updateView: false)
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
        rebuildChartData(updateView: true)
    }

    private func rebuildChartData(updateView: Bool) {
        guard view != nil else { return }
        let variants = chartModules
        let measurements = ruuviTagData
        let sensorSnapshot = sensor

        if variants.isEmpty {
            if updateView {
                view?.setChartViewData(from: [], settings: settings)
            }
            cacheCurrentChartData(entries: [:], measurements: measurements)
            return
        }

        let generation = nextChartDataGeneration()
        chartComputationQueue.async { [weak self] in
            guard let self else { return }
            let chartEntries = self.collectChartEntries(
                from: measurements,
                variants: variants
            )
            let models = self.buildChartModels(
                for: variants,
                entries: chartEntries,
                sensor: sensorSnapshot
            )

            DispatchQueue.main.async { [weak self] in
                guard let self,
                      generation == self.chartDataGeneration else { return }
                self.datasource = models
                if updateView {
                    self.view?.setChartViewData(from: models, settings: self.settings)
                    if let lastMeasurement = measurements.last {
                        self.updateLatestMeasurement(lastMeasurement)
                    }
                }
                self.cacheCurrentChartData(
                    entries: chartEntries,
                    measurements: measurements
                )
            }
        }
    }

    private func buildChartModels(
        for variants: [MeasurementDisplayVariant],
        entries: [MeasurementDisplayVariant: [ChartDataEntry]],
        sensor: AnyRuuviTagSensor?
    ) -> [RuuviGraphViewDataModel] {
        var models: [RuuviGraphViewDataModel] = []

        for variant in variants {
            guard let variantEntries = entries[variant], !variantEntries.isEmpty else {
                continue
            }

            let bounds = variantResolver.alertBounds(for: variant, sensor: sensor)
            let dataSet = RuuviGraphDataSetFactory.newDataSet(
                upperAlertValue: bounds.upper,
                entries: variantEntries,
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

        return models
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

    private func chartEntry(for data: RuuviMeasurement, variant: MeasurementDisplayVariant) -> ChartDataEntry? {
        guard
            let y = variantResolver.value(
                for: data,
                variant: variant,
                sensorSettings: sensorSettings,
                configuration: .cardsGraph
            ),
            y.isFinite
        else {
            return nil
        }

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

    private func filteredVariants(from modules: [MeasurementDisplayVariant]) -> [MeasurementDisplayVariant] {
        guard let visibility = snapshot?.displayData.measurementVisibility else {
            return modules
        }
        return modules.filter { variant in
            visibility.visibleVariants.contains(where: { $0 == variant })
        }
    }

    private func applyVisibilityChangeIfNeeded() {
        let orderedVariants = orderedChartMeasurementVariants()
        let filtered = filteredVariants(from: orderedVariants)
        guard filtered != chartModules else { return }
        chartModules = filtered
        view?.createChartViews(from: chartModules)
        createChartData()
        if let pending = pendingScrollRequest {
            scroll(to: pending.type, variant: pending.variant)
        }
    }

    private func orderedChartMeasurementVariants() -> [MeasurementDisplayVariant] {
        let profile: MeasurementDisplayProfile
        if let sensor {
            profile = RuuviTagDataService.measurementDisplayProfile(for: sensor)
        } else if let snapshot {
            profile = RuuviTagDataService.measurementDisplayProfile(for: snapshot)
        } else {
            profile = RuuviTagDataService.defaultMeasurementDisplayProfile()
        }

        return profile.orderedVisibleVariants(for: .graph)
    }
}
// swiftlint:enable file_length
