// swiftlint:disable file_length

import Foundation
import RuuviOntology
import RuuviLocal
import RuuviService
import RuuviStorage
import RuuviReactor
import BTKit
import DGCharts
import Combine
import RuuviLocalization

class MeasurementDetailsPresenter: NSObject {
    weak var view: MeasurementDetailsViewInput?

    // Dependencies
    private let settings: RuuviLocalSettings
    private let measurementService: RuuviServiceMeasurement
    private let alertService: RuuviServiceAlert
    private let ruuviStorage: RuuviStorage
    private let cloudSyncService: RuuviServiceCloudSync
    private let ruuviReactor: RuuviReactor
    private let localSyncState: RuuviLocalSyncState
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
    private weak var output: MeasurementDetailsPresenterOutput?

    // Thread-safe data management
    private let dataQueue = DispatchQueue(
        label: "com.ruuvi.measurementdetails.data",
        attributes: .concurrent
    )
    private var _ruuviTagData: [RuuviMeasurement] = []
    private var ruuviTagData: [RuuviMeasurement] {
        get { dataQueue.sync { _ruuviTagData } }
        set { dataQueue.async(flags: .barrier) { self._ruuviTagData = newValue } }
    }

    private var _lastMeasurementDate: Date?
    private var lastMeasurementDate: Date? {
        get { dataQueue.sync { _lastMeasurementDate } }
        set { dataQueue.async(flags: .barrier) { self._lastMeasurementDate = newValue } }
    }

    // State management
    private let stateQueue = DispatchQueue(label: "com.ruuvi.measurementdetails.state")
    private var _isDataLoaded = false
    private var isDataLoaded: Bool {
        get { stateQueue.sync { _isDataLoaded } }
        set { stateQueue.async { self._isDataLoaded = newValue } }
    }

    private var _isViewActive = false
    private var isViewActive: Bool {
        get { stateQueue.sync { _isViewActive } }
        set { stateQueue.async { self._isViewActive = newValue } }
    }

    // Observation tokens
    private var unitChangeTokens: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    // Configuration constants
    private let highDensityIntervalMinutes: Int = 15
    private let maximumPointsCount: Double = 3000.0
    private let minimumDownsampleThreshold: Int = 1000
    private let defaultDurationHours: Int = 48

    init(
        settings: RuuviLocalSettings,
        measurementService: RuuviServiceMeasurement,
        alertService: RuuviServiceAlert,
        ruuviStorage: RuuviStorage,
        cloudSyncService: RuuviServiceCloudSync,
        ruuviReactor: RuuviReactor,
        localSyncState: RuuviLocalSyncState
    ) {
        self.settings = settings
        self.measurementService = measurementService
        self.alertService = alertService
        self.ruuviStorage = ruuviStorage
        self.cloudSyncService = cloudSyncService
        self.ruuviReactor = ruuviReactor
        self.localSyncState = localSyncState
        super.init()
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
        guard !isViewActive else { return }

        isViewActive = true
        setupObservers()
        loadInitialData()
    }

    func stop() {
        isViewActive = false
        removeAllObservers()
    }

    private func resetState() {
        isDataLoaded = false
        ruuviTagData = []
        lastMeasurementDate = nil
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
        loadInitialData()
    }
}

// MARK: - Data Loading

private extension MeasurementDetailsPresenter {

    func loadInitialData() {
        loadHistoricalData { [weak self] in
            self?.syncCloudDataIfNeeded()
        }
    }

    func loadHistoricalData(completion: (() -> Void)? = nil) {
        let fromDate = Calendar.current.date(
            byAdding: .hour,
            value: -defaultDurationHours,
            to: Date()
        ) ?? Date.distantPast

        let shouldDownsample = !settings.chartShowAllMeasurements

        if shouldDownsample {
            loadWithDownsamplingCheck(from: fromDate, completion: completion)
        } else {
            loadAllData(from: fromDate, completion: completion)
        }
    }

    func loadAllData(from date: Date, completion: (() -> Void)? = nil) {
        Task { [weak self] in
            guard let self else {
                completion?()
                return
            }
            do {
                let results = try await ruuviStorage.read(
                    ruuviTag.id,
                    after: date,
                    with: TimeInterval(2)
                )
                handleDataLoaded(results.map(\.measurement))
            } catch {
                handleDataLoadError()
            }
            completion?()
        }
    }

    func loadWithDownsamplingCheck(from date: Date, completion: (() -> Void)? = nil) {

        Task { [weak self] in
            guard let self else {
                completion?()
                return
            }
            do {
                let results = try await ruuviStorage.read(
                    ruuviTag.id,
                    after: date,
                    with: TimeInterval(2)
                )
                if results.count < minimumDownsampleThreshold {
                    handleDataLoaded(results.map(\.measurement))
                    completion?()
                } else {
                    loadDownsampledData(from: date, completion: completion)
                }
            } catch {
                handleDataLoadError()
                completion?()
            }
        }
    }

    func loadDownsampledData(from date: Date, completion: (() -> Void)? = nil) {
        Task { [weak self] in
            guard let self else {
                completion?()
                return
            }
            do {
                let results = try await ruuviStorage.readDownsampled(
                    ruuviTag.id,
                    after: date,
                    with: highDensityIntervalMinutes,
                    pick: maximumPointsCount
                )
                handleDataLoaded(results.map(\.measurement))
            } catch {
                handleDataLoadError()
            }
            completion?()
        }
    }

    func handleDataLoaded(_ measurements: [RuuviMeasurement]) {
        // Sort measurements by date to ensure correct order
        let sortedMeasurements = measurements.sorted { $0.date < $1.date }

        ruuviTagData = sortedMeasurements
        lastMeasurementDate = sortedMeasurements.last?.date
        isDataLoaded = true

        DispatchQueue.main.async { [weak self] in
            self?.updateChart()
        }
    }

    func handleDataLoadError() {
        ruuviTagData = []
        isDataLoaded = true

        DispatchQueue.main.async { [weak self] in
            self?.view?.setNoDataLabelVisibility(show: true)
        }
    }

    func loadLatestMeasurements() {
        guard let ruuviTag = ruuviTag,
              let lastDate = lastMeasurementDate,
              isDataLoaded else { return }

        Task { [weak self] in
            guard let self else { return }
            let results = try? await ruuviStorage.readLast(
                ruuviTag.id,
                from: lastDate.timeIntervalSince1970
            )
            guard let results else { return }

            // Filter out duplicates and only add truly new measurements
            let newMeasurements = results
                .map(\.measurement)
                .filter { measurement in
                    measurement.date > lastDate
                }
                .sorted { $0.date < $1.date }

            guard !newMeasurements.isEmpty else { return }

            appendNewMeasurements(newMeasurements)
        }
    }

    func appendNewMeasurements(_ newMeasurements: [RuuviMeasurement]) {
        dataQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Append new measurements
            self._ruuviTagData.append(contentsOf: newMeasurements)

            // Update last measurement date
            if let lastNew = newMeasurements.last {
                self._lastMeasurementDate = lastNew.date
            }

            // Prune old data if needed
            if self.settings.chartShowAllMeasurements {
                let cutoffDate = Calendar.current.date(
                    byAdding: .hour,
                    value: -self.settings.dataPruningOffsetHours,
                    to: Date()
                ) ?? Date.distantPast

                self._ruuviTagData.removeAll { $0.date < cutoffDate }
            }

            // Update chart on main thread
            DispatchQueue.main.async { [weak self] in
                self?.appendDataToChart(newMeasurements)
            }
        }
    }
}

// MARK: - Chart Management

private extension MeasurementDetailsPresenter {

    func updateChart() {
        guard isDataLoaded, isViewActive else { return }

        let measurements = ruuviTagData

        // Check if we have valid data for this measurement type
        let variant = resolvedVariant
        let hasValidData = !measurements.isEmpty && measurements.contains { measurement in
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
            view?.updateChartData(entries, settings: settings)
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

        let bounds = variantResolver.alertBounds(for: variant, sensor: sensor.any)
        let upperAlert = bounds.upper
        let lowerAlert = bounds.lower

        let dataSet = RuuviGraphDataSetFactory.simpleGraphDataSet(
            upperAlertValue: upperAlert,
            entries: entries,
            lowerAlertValue: lowerAlert,
            showAlertRangeInGraph: false
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
              let grid = data.indicatorGrid else {
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
}

// MARK: - Cloud Sync

private extension MeasurementDetailsPresenter {

    func syncCloudDataIfNeeded() {
        guard ruuviTag.isCloud,
              isViewActive else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await cloudSyncService.sync(sensor: ruuviTag)
            } catch {
                return
            }
            guard self.isViewActive else { return }
            // Reload data after sync completes
            loadHistoricalData()
        }
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
           visibility.visibleVariants.contains(where: { $0 == preferred }) {
            return preferred
        }
        if let replacement = visibility.visibleVariants.first(where: { $0.type.isSameCase(as: type) }) {
            return replacement
        }
        return preferred ?? defaultVariant(for: type)
    }
}

// swiftlint:enable file_length
