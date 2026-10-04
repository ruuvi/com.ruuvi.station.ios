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
    private let ruuviReactor: RuuviReactor
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

    private var isViewActive = false

    // Observation tokens
    private var unitChangeTokens: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    private var historyCancellation = RuuviHistoryCancellation()
    private var historyTimer: Timer?

    private let defaultDurationHours = 48

    init(
        settings: RuuviLocalSettings,
        flags _: RuuviLocalFlags,
        measurementService: RuuviServiceMeasurement,
        alertService: RuuviServiceAlert,
        ruuviStorage: RuuviStorage,
        cloudSyncService _: RuuviServiceCloudSync,
        ruuviReactor: RuuviReactor,
        localSyncState _: RuuviLocalSyncState
    ) {
        self.settings = settings
        self.measurementService = measurementService
        self.alertService = alertService
        self.ruuviStorage = ruuviStorage
        self.ruuviReactor = ruuviReactor
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

    }

    func start() {
        guard !isViewActive else { return }

        isViewActive = true
        setupObservers()
        loadInitialData()
        historyTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.loadHistoricalData() }
    }

    func stop() {
        isViewActive = false
        historyCancellation.cancel()
        historyTimer?.invalidate()
        historyTimer = nil
        removeAllObservers()
    }

    private func resetState() {
        historyCancellation.cancel()
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
        loadInitialData()
    }
}

// MARK: - Data Loading

private extension MeasurementDetailsPresenter {

    func loadInitialData() { loadHistoricalData() }

    func updateChart() { loadHistoricalData() }

    func loadHistoricalData(completion: (() -> Void)? = nil) {
        guard isViewActive, let sensor = ruuviTag else { completion?(); return }
        historyCancellation.cancel()
        let cancellation = RuuviHistoryCancellation()
        historyCancellation = cancellation
        let range = RuuviHistorySelection.rolling(hours: defaultDurationHours).resolve()
        let sampler = RuuviHistorySampler(range: range)
        let variant = resolvedVariant
        let resolver = variantResolver
        let sensorSettings = sensorSettings
        ruuviStorage.scanHistory(sensor.id, range: range, cancellation: cancellation) { record in
            sampler.add(date: record.date, value: resolver.value(for: record.measurement, variant: variant, sensorSettings: sensorSettings))
        }.on(success: { [weak self] completed in
            DispatchQueue.main.async {
                guard let self, completed >= 0, !cancellation.isCancelled, self.isViewActive else { return }
                let series = sampler.finish()
                let bounds = self.alertRangeBounds(for: variant, sensor: sensor)
                self.currentAlertRangeFingerprint = self.alertRangeFingerprint(for: variant, bounds: bounds)
                let data = RuuviHistoryChartData(series: series, selectedRange: range, sampledRange: range,
                    upper: bounds.upper, lower: bounds.lower, showAlerts: self.shouldShowAlertRangeInGraph(for: variant),
                    drawDots: self.settings.chartDrawDotsOn)
                self.view?.setChartData(RuuviGraphViewDataModel(upperAlertValue: bounds.upper, variant: variant,
                    chartData: data, lowerAlertValue: bounds.lower), settings: self.settings, displayType: variant.type,
                    unit: variant.type.unit(for: variant, settings: self.settings), measurementService: self.measurementService)
                self.view?.setNoDataLabelVisibility(show: series.points.isEmpty)
                completion?()
            }
        }, failure: { [weak self] _ in
            DispatchQueue.main.async { if !cancellation.isCancelled { self?.view?.setNoDataLabelVisibility(show: true); completion?() } }
        })
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
              let alertType = variant.toAlertType() else {
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
