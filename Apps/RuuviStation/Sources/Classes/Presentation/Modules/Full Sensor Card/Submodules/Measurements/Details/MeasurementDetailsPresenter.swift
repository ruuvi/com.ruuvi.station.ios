// swiftlint:disable file_length

import Foundation
import RuuviOntology
import RuuviLocal
import RuuviService
import RuuviStorage
import DGCharts
import Combine
import RuuviLocalization

class MeasurementDetailsPresenter: NSObject {
    weak var view: MeasurementDetailsViewInput?

    // Dependencies
    private let settings: RuuviLocalSettings
    private let flags: RuuviLocalFlags
    private let measurementService: RuuviServiceMeasurement
    private let alertService: RuuviServiceAlert
    private let ruuviStorage: RuuviStorage
    private let cloudSyncService: RuuviServiceCloudSync
    private lazy var variantResolver = MeasurementVariantResolver(
        settings: settings,
        measurementService: measurementService,
        alertService: alertService
    )

    // Properties
    private var snapshot: RuuviTagCardSnapshot!
    private var ruuviTag: RuuviTagSensor!
    private var sensorSettings: SensorSettings?
    private var measurementVariant: MeasurementDisplayVariant?
    private var measurementType: MeasurementType = .temperature
    private var resolvedVariant: MeasurementDisplayVariant {
        if let measurementVariant {
            return measurementVariant
        }
        return defaultVariant(for: measurementType)
    }
    private struct AlertRangeFingerprint: Equatable {
        let showAlertRange: Bool
        let variant: MeasurementDisplayVariant
        let isActive: Bool
        let lower: Double?
        let upper: Double?
    }
    private var currentAlertRangeFingerprint: AlertRangeFingerprint?
    private weak var output: MeasurementDetailsPresenterOutput?

    // UIKit and the subscriptions below access presentation state on the main thread.
    // Requests carry a generation because a storage implementation may complete after cancellation.
    private var ruuviTagData: [RuuviMeasurement] = []
    private var lastMeasurementDate: Date?
    private var isDataLoaded = false
    private var isViewActive = false
    private var requestGeneration = UUID()
    private var historyTask: Task<Void, Never>?
    private var latestTask: Task<Void, Never>?
    private var latestReadPending = false

    // Observation tokens
    private var unitChangeTokens: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    // Configuration constants
    private let highDensityIntervalMinutes: Int = 15
    private let minimumDownsampleThreshold: Int = 1000
    private let defaultDurationHours: Int = 48
    private var maximumPointsCount: Double {
        Double(min(5000, max(1000, flags.graphDownsampleMaximumPoints)))
    }

    init(
        settings: RuuviLocalSettings,
        flags: RuuviLocalFlags,
        measurementService: RuuviServiceMeasurement,
        alertService: RuuviServiceAlert,
        ruuviStorage: RuuviStorage,
        cloudSyncService: RuuviServiceCloudSync
    ) {
        self.settings = settings
        self.flags = flags
        self.measurementService = measurementService
        self.alertService = alertService
        self.ruuviStorage = ruuviStorage
        self.cloudSyncService = cloudSyncService
        super.init()
    }

    deinit {
        historyTask?.cancel()
        latestTask?.cancel()
        unitChangeTokens.forEach(NotificationCenter.default.removeObserver)
    }
}

// MARK: - MeasurementDetailsPresenterInput

extension MeasurementDetailsPresenter: MeasurementDetailsPresenterInput {

    // swiftlint:disable:next function_parameter_count
    func configure(
        with snapshot: RuuviTagCardSnapshot,
        measurementType: MeasurementType,
        variant: MeasurementDisplayVariant?,
        ruuviTag: RuuviTagSensor,
        sensorSettings: SensorSettings?,
        output: MeasurementDetailsPresenterOutput
    ) {
        stop()
        self.ruuviTag = ruuviTag
        self.snapshot = snapshot
        self.measurementType = measurementType
        self.measurementVariant = resolveVisibleVariant(
            for: measurementType,
            preferred: variant
        )
        self.sensorSettings = sensorSettings
        self.output = output

        // Reset state for new configuration
        resetState()

        // Set initial last measurement date from snapshot
        self.lastMeasurementDate = snapshot.latestRawRecord?.measurement.date
    }

    func start() {
        guard !isViewActive, snapshot != nil, ruuviTag != nil else { return }

        isViewActive = true
        setupObservers()
        loadHistoricalData(syncCloud: true)
    }

    func stop() {
        isViewActive = false
        requestGeneration = UUID()
        historyTask?.cancel()
        historyTask = nil
        latestTask?.cancel()
        latestTask = nil
        latestReadPending = false
        removeAllObservers()
    }

    private func resetState() {
        isDataLoaded = false
        ruuviTagData = []
        lastMeasurementDate = nil
        currentAlertRangeFingerprint = nil
    }
}

// MARK: - MeasurementDetailsViewOutput

extension MeasurementDetailsPresenter: MeasurementDetailsViewOutput {
    func viewDidLoad() {
        start()
    }

    func didTapGraph() {
        output?.detailsViewDidDismiss(
            for: snapshot,
            measurement: measurementType,
            variant: resolvedVariant,
            ruuviTag: ruuviTag,
            module: self
        )
    }

    func didTapMeasurement(_ measurement: RuuviTagCardSnapshotIndicatorData) {
        measurementVariant = measurement.variant
        measurementType = measurement.type
        loadHistoricalData(syncCloud: true)
    }
}

// MARK: - Data Loading

private extension MeasurementDetailsPresenter {
    func loadHistoricalData(syncCloud: Bool = false) {
        guard isViewActive, let sensor = ruuviTag else { return }
        historyTask?.cancel()
        latestTask?.cancel()
        latestTask = nil
        latestReadPending = false
        isDataLoaded = false
        let generation = UUID()
        requestGeneration = generation
        let fromDate = RuuviHistoryWindow.start(
            limitHours: settings.dataPruningOffsetHours, requestedHours: defaultDurationHours
        )
        let shouldDownsample = !settings.chartShowAllMeasurements
        let maximumPoints = maximumPointsCount
        let interval = highDensityIntervalMinutes
        let threshold = minimumDownsampleThreshold
        historyTask = Task { @MainActor [weak self, ruuviStorage, cloudSyncService] in
            do {
                var records = try await ruuviStorage.read(sensor.id, after: fromDate, with: 2)
                guard !Task.isCancelled else { return }
                if shouldDownsample, records.count >= threshold {
                    records = try await ruuviStorage.readDownsampled(
                        sensor.id, after: fromDate, with: interval, pick: maximumPoints
                    )
                }
                guard !Task.isCancelled, self?.requestGeneration == generation else { return }
                self?.handleDataLoaded(records.map(\.measurement))
            } catch {
                guard !Task.isCancelled, self?.requestGeneration == generation else { return }
                self?.ruuviTagData = []
                self?.lastMeasurementDate = nil
                self?.isDataLoaded = true
                self?.view?.setNoDataLabelVisibility(show: true)
            }
            guard syncCloud, sensor.isCloud, !Task.isCancelled,
                self?.isViewActive == true, self?.requestGeneration == generation
            else { return }
            do {
                try await cloudSyncService.sync(sensor: sensor)
                guard !Task.isCancelled, self?.requestGeneration == generation else { return }
                self?.loadHistoricalData()
            } catch {
                // Retain the available local chart when an online refresh fails.
            }
        }
    }

    func handleDataLoaded(_ measurements: [RuuviMeasurement]) {
        ruuviTagData = orderedUniqueMeasurements(measurements)
        lastMeasurementDate = ruuviTagData.last?.date
        isDataLoaded = true
        updateChart()
        if latestReadPending {
            latestReadPending = false
            loadLatestMeasurements()
        }
    }

    func orderedUniqueMeasurements(_ measurements: [RuuviMeasurement]) -> [RuuviMeasurement] {
        var dates = Set<Date>()
        return measurements.filter { $0.date.timeIntervalSince1970.isFinite && dates.insert($0.date).inserted }
            .sorted { $0.date < $1.date }
    }

    func loadLatestMeasurements() {
        guard isViewActive, let sensor = ruuviTag else { return }
        guard isDataLoaded, latestTask == nil else {
            latestReadPending = true
            return
        }
        guard let lastDate = lastMeasurementDate else {
            loadHistoricalData()
            return
        }
        let generation = requestGeneration
        latestTask = Task { @MainActor [weak self, ruuviStorage] in
            defer {
                if self?.requestGeneration == generation {
                    self?.latestTask = nil
                    if self?.latestReadPending == true {
                        self?.latestReadPending = false
                        self?.loadLatestMeasurements()
                    }
                }
            }
            do {
                let records = try await ruuviStorage.readLast(sensor.id, from: lastDate.timeIntervalSince1970)
                guard !Task.isCancelled, self?.requestGeneration == generation else { return }
                self?.appendNewMeasurements(records.map(\.measurement).filter { $0.date > lastDate })
            } catch {
                // A later reading can retry without clearing valid chart history.
            }
        }
    }

    func appendNewMeasurements(_ measurements: [RuuviMeasurement]) {
        let newMeasurements = orderedUniqueMeasurements(measurements)
        guard !newMeasurements.isEmpty else { return }
        let cutoffDate = RuuviHistoryWindow.start(
            limitHours: settings.dataPruningOffsetHours, requestedHours: defaultDurationHours
        )
        let visible = newMeasurements.filter { $0.date >= cutoffDate }
        let expired = ruuviTagData.contains { $0.date < cutoffDate }
        ruuviTagData = ruuviTagData.filter { $0.date >= cutoffDate } + visible
        lastMeasurementDate = newMeasurements.last?.date
        if expired {
            updateChart()
        } else {
            appendDataToChart(visible)
        }
    }
}

// MARK: - Chart Management

private extension MeasurementDetailsPresenter {

    func updateChart(with measurements: [RuuviMeasurement]? = nil) {
        guard isDataLoaded, isViewActive else { return }

        let measurements = measurements ?? ruuviTagData

        // Check if we have valid data for this measurement type
        let variant = resolvedVariant
        let hasValidData =
            !measurements.isEmpty
            && measurements.contains { measurement in
                variantResolver.value(
                    for: measurement,
                    variant: variant,
                    sensorSettings: sensorSettings
                ) != nil
            }

        guard hasValidData else {
            view?.setNoDataLabelVisibility(show: true)
            return
        }

        // Build chart entries
        var entries: [ChartDataEntry] = []
        for measurement in measurements {
            if let value = variantResolver.value(
                for: measurement,
                variant: variant,
                sensorSettings: sensorSettings
            ), value.isFinite {
                let x = measurement.date.timeIntervalSince1970
                guard x.isFinite else { continue }

                entries.append(ChartDataEntry(x: x, y: value))
            }
        }

        guard !entries.isEmpty else {
            view?.setNoDataLabelVisibility(show: true)
            return
        }

        view?.setNoDataLabelVisibility(show: false)

        let chartData = createChartData(entries: entries)
        view?
            .setChartData(
                chartData,
                settings: settings,
                displayType: variant.type,
                unit: variant.type
                    .unit(
                        for: variant,
                        settings: settings
                    ),
                measurementService: measurementService
            )
    }

    func appendDataToChart(_ measurements: [RuuviMeasurement]) {
        guard isViewActive else { return }

        var entries: [ChartDataEntry] = []

        let variant = resolvedVariant
        for measurement in measurements {
            if let value = variantResolver.value(
                for: measurement,
                variant: variant,
                sensorSettings: sensorSettings
            ), value.isFinite {
                let x = measurement.date.timeIntervalSince1970
                guard x.isFinite else { continue }

                entries.append(ChartDataEntry(x: x, y: value))
            }
        }

        if !entries.isEmpty {
            view?.setNoDataLabelVisibility(show: false)
            view?.updateChartData(
                entries,
                showAlertRangeInGraph: shouldShowAlertRangeInGraph(for: variant)
            )
        }
    }

    func createChartData(entries: [ChartDataEntry]) -> RuuviGraphViewDataModel {
        let variant = resolvedVariant

        guard let sensor = ruuviTag else {
            return RuuviGraphViewDataModel(
                upperAlertValue: nil,
                variant: variant,
                chartData: LineChartData(dataSets: []),
                lowerAlertValue: nil
            )
        }

        let bounds = alertRangeBounds(for: variant, sensor: sensor)
        let upperAlert = bounds.upper
        let lowerAlert = bounds.lower
        let shouldShowAlertRange = shouldShowAlertRangeInGraph(for: variant)
        currentAlertRangeFingerprint = alertRangeFingerprint(
            for: variant,
            bounds: bounds
        )

        let dataSet = RuuviGraphDataSetFactory.simpleGraphDataSet(
            upperAlertValue: upperAlert,
            entries: entries,
            lowerAlertValue: lowerAlert,
            showAlertRangeInGraph: shouldShowAlertRange
        )

        return RuuviGraphViewDataModel(
            upperAlertValue: upperAlert,
            variant: variant,
            chartData: LineChartData(dataSet: dataSet),
            lowerAlertValue: lowerAlert
        )
    }

    func setupObservers() {
        setupUnitChangeObservers()

        cancellables
            .removeAll()

        snapshot.$latestRawRecord
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] record in
                guard record != nil else { return }
                self?.loadLatestMeasurements()
            }
            .store(in: &cancellables)

        // Subscribe to data changes
        snapshot.$displayData
            .receive(
                on: DispatchQueue.main
            )
            .sink { [weak self] displayData in
                guard let self else { return }
                self.view?.updateMeasurements(
                    with: self.filteredDisplayData(from: displayData)
                )
            }
            .store(
                in: &cancellables
            )

        snapshot.$alertData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.view?.updateAlertStates()
                self?.updateChartAlertRangeIfNeeded()
            }
            .store(in: &cancellables)

        snapshot.$metadata
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.view?.updateAlertStates()
            }
            .store(in: &cancellables)
    }

    func setupUnitChangeObservers() {
        let temperatureToken = NotificationCenter.default.addObserver(
            forName: .TemperatureUnitDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self?.measurementType == .temperature else { return }
            self?.updateChart()
        }

        let humidityToken = NotificationCenter.default.addObserver(
            forName: .HumidityUnitDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard case .humidity = self?.measurementType else { return }
            self?.updateChart()
        }

        let pressureToken = NotificationCenter.default.addObserver(
            forName: .PressureUnitDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self?.measurementType == .pressure else { return }
            self?.updateChart()
        }

        unitChangeTokens = [temperatureToken, humidityToken, pressureToken]
    }

    func removeAllObservers() {
        cancellables.removeAll()
        unitChangeTokens.forEach { NotificationCenter.default.removeObserver($0) }
        unitChangeTokens.removeAll()
    }

    func filteredDisplayData(
        from data: RuuviTagCardSnapshotDisplayData
    ) -> RuuviTagCardSnapshotDisplayData {
        guard let visibility = snapshot?.displayData.measurementVisibility,
            let grid = data.indicatorGrid
        else {
            return data
        }

        let visibleIndicators = grid.indicators.filter { indicator in
            visibility.visibleVariants.contains(where: { $0 == indicator.variant })
        }

        guard !visibleIndicators.isEmpty else {
            return data
        }

        var copy = data
        copy.indicatorGrid = RuuviTagCardSnapshotIndicatorGridConfiguration(
            indicators: visibleIndicators
        )
        return copy
    }

    func updateChartAlertRangeIfNeeded() {
        let variant = resolvedVariant
        let bounds = alertRangeBounds(for: variant, sensor: ruuviTag)
        let fingerprint = alertRangeFingerprint(
            for: variant,
            bounds: bounds
        )
        guard fingerprint != currentAlertRangeFingerprint else { return }
        updateChart()
    }

    func shouldShowAlertRangeInGraph(for variant: MeasurementDisplayVariant) -> Bool {
        guard settings.showAlertsRangeInGraph,
            let alertType = variant.toAlertType()
        else {
            return false
        }
        if let config = snapshot.getAlertConfig(for: alertType) {
            return config.isActive
        }
        return alertService.isOn(type: alertType, for: ruuviTag.any)
    }

    func alertRangeBounds(
        for variant: MeasurementDisplayVariant,
        sensor: RuuviTagSensor
    ) -> (lower: Double?, upper: Double?) {
        let alertConfig = variant.toAlertType().flatMap {
            snapshot.getAlertConfig(for: $0)
        }
        return variantResolver.alertBounds(
            for: variant,
            sensor: sensor.any,
            alertConfig: alertConfig
        )
    }

    private func alertRangeFingerprint(
        for variant: MeasurementDisplayVariant,
        bounds: (lower: Double?, upper: Double?)
    ) -> AlertRangeFingerprint {
        let isRangeVisible = shouldShowAlertRangeInGraph(for: variant)
        return AlertRangeFingerprint(
            showAlertRange: settings.showAlertsRangeInGraph,
            variant: variant,
            isActive: isRangeVisible,
            lower: isRangeVisible ? bounds.lower : nil,
            upper: isRangeVisible ? bounds.upper : nil
        )
    }
}

private extension MeasurementDetailsPresenter {
    func defaultVariant(for type: MeasurementType) -> MeasurementDisplayVariant {
        switch type {
        case .humidity:
            return MeasurementDisplayVariant(
                type: .humidity,
                humidityUnit: settings.humidityUnit
            )
        default:
            return MeasurementDisplayVariant(type: type)
        }
    }

    func resolveVisibleVariant(
        for type: MeasurementType,
        preferred: MeasurementDisplayVariant?
    ) -> MeasurementDisplayVariant {
        guard let visibility = snapshot?.displayData.measurementVisibility else {
            return preferred ?? defaultVariant(for: type)
        }
        if let preferred,
            visibility.visibleVariants.contains(where: { $0 == preferred })
        {
            return preferred
        }
        if let replacement = visibility.visibleVariants.first(where: { $0.type.isSameCase(as: type) }) {
            return replacement
        }
        return preferred ?? defaultVariant(for: type)
    }
}

// swiftlint:enable file_length
