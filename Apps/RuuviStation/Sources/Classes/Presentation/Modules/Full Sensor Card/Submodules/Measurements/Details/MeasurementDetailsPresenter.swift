// swiftlint:disable file_length

import Foundation
import RuuviOntology
import RuuviLocal
import RuuviService
import RuuviStorage
import RuuviReactor
import BTKit
import DGCharts

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

    // Properties
    private var snapshot: RuuviTagCardSnapshot!
    private var ruuviTag: RuuviTagSensor!
    private var sensorSettings: SensorSettings?
    private var measurementType: MeasurementType = .temperature
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

    func configure(
        with snapshot: RuuviTagCardSnapshot,
        measurementType: MeasurementType,
        ruuviTag: RuuviTagSensor,
        sensorSettings: SensorSettings?,
        output: MeasurementDetailsPresenterOutput
    ) {
        self.ruuviTag = ruuviTag
        self.snapshot = snapshot
        self.measurementType = measurementType
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
            ruuviTag: ruuviTag,
            module: self
        )
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
            guard let self = self else { return }
            do {
                let results = try await self.readMeasurements(after: date, sampling: 2)
                self.handleDataLoaded(results.map(\.measurement))
            } catch {
                self.handleDataLoadError()
            }
            completion?()
        }
    }

    func loadWithDownsamplingCheck(from date: Date, completion: (() -> Void)? = nil) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let results = try await self.readMeasurements(after: date, sampling: 2)
                if results.count < self.minimumDownsampleThreshold {
                    self.handleDataLoaded(results.map(\.measurement))
                    completion?()
                } else {
                    self.loadDownsampledData(from: date, completion: completion)
                }
            } catch {
                self.handleDataLoadError()
                completion?()
            }
        }
    }

    func loadDownsampledData(from date: Date, completion: (() -> Void)? = nil) {
//        Task { [weak self] in
//            guard let self = self else { return }
//            do {
//                let results = try await self.readDownsampledMeasurements(after: date,
//                                                                         intervalMinutes: highDensityIntervalMinutes,
//                                                                         pick: maximumPointsCount)
//                self.handleDataLoaded(results.map(\.measurement))
//            } catch {
//                self.handleDataLoadError()
//            }
//            completion?()
//        }
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
            guard let self = self else { return }
            do {
                let results = try await self.readLastMeasurements(from: lastDate.timeIntervalSince1970)
                let newMeasurements = results
                    .map(\.measurement)
                    .filter { $0.date > lastDate }
                    .sorted { $0.date < $1.date }
                guard !newMeasurements.isEmpty else { return }
                self.appendNewMeasurements(newMeasurements)
            } catch { /* ignore */ }
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
        let hasValidData = !measurements.isEmpty && measurements.contains { measurement in
            chartValue(for: measurement) != nil
        }

        guard hasValidData else {
            view?.setNoDataLabelVisibility(show: true)
            return
        }

        // Build chart entries
        var entries: [ChartDataEntry] = []
        for measurement in measurements {
            if let value = chartValue(for: measurement),
               value.isFinite {
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
        view?.setChartData(chartData, settings: settings)
    }

    func appendDataToChart(_ measurements: [RuuviMeasurement]) {
        guard isViewActive else { return }

        var entries: [ChartDataEntry] = []

        for measurement in measurements {
            if let value = chartValue(for: measurement),
               value.isFinite {
                let x = measurement.date.timeIntervalSince1970
                guard x.isFinite else { continue }

                entries.append(ChartDataEntry(x: x, y: value))
            }
        }

        if !entries.isEmpty {
            view?.updateChartData(entries, settings: settings)
        }
    }

    func createChartData(entries: [ChartDataEntry]) -> TagChartViewData {
        guard let sensor = ruuviTag else {
            return TagChartViewData(
                upperAlertValue: nil,
                chartType: measurementType,
                chartData: LineChartData(dataSets: []),
                lowerAlertValue: nil
            )
        }

        let isAlertOn = isAlertEnabled(for: measurementType, sensor: sensor.any)
        let upperAlert = isAlertOn ? getUpperAlert(for: measurementType, sensor: sensor.any) : nil
        let lowerAlert = isAlertOn ? getLowerAlert(for: measurementType, sensor: sensor.any) : nil

        let dataSet = TagChartsHelper.simpleGraphDataSet(
            upperAlertValue: upperAlert,
            entries: entries,
            lowerAlertValue: lowerAlert,
            showAlertRangeInGraph: false
        )

        return TagChartViewData(
            upperAlertValue: upperAlert,
            chartType: measurementType,
            chartData: LineChartData(dataSet: dataSet),
            lowerAlertValue: lowerAlert
        )
    }

    // swiftlint:disable:next cyclomatic_complexity
    func chartValue(for measurement: RuuviMeasurement) -> Double? {
        switch measurementType {
        case .temperature:
            let temp = measurement.temperature?.plus(sensorSettings: sensorSettings)
            return measurementService.double(for: temp)

        case .humidity:
            let humidity = measurement.humidity?.plus(sensorSettings: sensorSettings)
            return measurementService.double(
                for: humidity,
                temperature: measurement.temperature,
                isDecimal: false
            )

        case .pressure:
            let pressure = measurement.pressure?.plus(sensorSettings: sensorSettings)
            return measurementService.double(for: pressure)

        case .aqi:
            let (aqi, _, _) = measurementService.aqi(for: measurement.co2, pm25: measurement.pm25)
            return Double(aqi)

        case .co2:
            return measurementService.double(for: measurement.co2)

        case .pm25:
            return measurementService.double(for: measurement.pm25)

        case .pm100:
            return measurementService.double(for: measurement.pm10)

        case .voc:
            return measurementService.double(for: measurement.voc)

        case .nox:
            return measurementService.double(for: measurement.nox)

        case .luminosity:
            return measurementService.double(for: measurement.luminosity)

        case .soundInstant:
            return measurementService.double(for: measurement.soundInstant)

        default:
            return nil
        }
    }
}

// MARK: - Alert Helpers

private extension MeasurementDetailsPresenter {

    // swiftlint:disable:next cyclomatic_complexity
    func isAlertEnabled(for type: MeasurementType, sensor: AnyRuuviTagSensor) -> Bool {
        switch type {
        case .temperature:
            return alertService.isOn(type: .temperature(lower: 0, upper: 0), for: sensor)
        case .humidity:
            return alertService.isOn(type: .relativeHumidity(lower: 0, upper: 0), for: sensor)
        case .pressure:
            return alertService.isOn(type: .pressure(lower: 0, upper: 0), for: sensor)
        case .aqi:
            return alertService.isOn(type: .aqi(lower: 0, upper: 0), for: sensor)
        case .co2:
            return alertService.isOn(type: .carbonDioxide(lower: 0, upper: 0), for: sensor)
        case .pm25:
            return alertService.isOn(type: .pMatter25(lower: 0, upper: 0), for: sensor)
        case .pm100:
            return alertService.isOn(type: .pMatter10(lower: 0, upper: 0), for: sensor)
        case .voc:
            return alertService.isOn(type: .voc(lower: 0, upper: 0), for: sensor)
        case .nox:
            return alertService.isOn(type: .nox(lower: 0, upper: 0), for: sensor)
        case .luminosity:
            return alertService.isOn(type: .luminosity(lower: 0, upper: 0), for: sensor)
        case .soundInstant:
            return alertService.isOn(type: .soundInstant(lower: 0, upper: 0), for: sensor)
        default:
            return false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func getUpperAlert(for type: MeasurementType, sensor: AnyRuuviTagSensor) -> Double? {
        switch type {
        case .temperature:
            return alertService.upperCelsius(for: sensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map { measurementService.double(for: $0) }
        case .humidity:
            let isRelative = measurementService.units.humidityUnit == .percent
            return isRelative ? alertService.upperRelativeHumidity(for: sensor).map { $0 * 100 } : nil
        case .pressure:
            return alertService.upperPressure(for: sensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map { measurementService.double(for: $0) }
        case .co2:
            return alertService.upperCarbonDioxide(for: sensor)
        case .aqi:
            return alertService.upperAQI(for: sensor)
        case .pm25:
            return alertService.upperPM25(for: sensor)
        case .pm100:
            return alertService.upperPM10(for: sensor)
        case .voc:
            return alertService.upperVOC(for: sensor)
        case .nox:
            return alertService.upperNOX(for: sensor)
        case .luminosity:
            return alertService.upperLuminosity(for: sensor)
        case .soundInstant:
            return alertService.upperSoundInstant(for: sensor)
        default:
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func getLowerAlert(for type: MeasurementType, sensor: AnyRuuviTagSensor) -> Double? {
        switch type {
        case .temperature:
            return alertService.lowerCelsius(for: sensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map { measurementService.double(for: $0) }
        case .humidity:
            let isRelative = measurementService.units.humidityUnit == .percent
            return isRelative ? alertService.lowerRelativeHumidity(for: sensor).map { $0 * 100 } : nil
        case .pressure:
            return alertService.lowerPressure(for: sensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map { measurementService.double(for: $0) }
        case .co2:
            return alertService.lowerCarbonDioxide(for: sensor)
        case .aqi:
            return alertService.lowerAQI(for: sensor)
        case .pm25:
            return alertService.lowerPM25(for: sensor)
        case .pm100:
            return alertService.lowerPM10(for: sensor)
        case .voc:
            return alertService.lowerVOC(for: sensor)
        case .nox:
            return alertService.lowerNOX(for: sensor)
        case .luminosity:
            return alertService.lowerLuminosity(for: sensor)
        case .soundInstant:
            return alertService.lowerSoundInstant(for: sensor)
        default:
            return nil
        }
    }
}

// MARK: - Observers

private extension MeasurementDetailsPresenter {

    func setupObservers() {
        setupUnitChangeObservers()
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
        unitChangeTokens.forEach { NotificationCenter.default.removeObserver($0) }
        unitChangeTokens.removeAll()
    }
}

// MARK: - Cloud Sync

private extension MeasurementDetailsPresenter {

    func syncCloudDataIfNeeded() {
        guard ruuviTag.isCloud,
              isViewActive else { return }
        Task { [weak self] in
            guard let self = self else { return }
            do {
                _ = try await self.syncCloud(sensor: self.ruuviTag)
                guard self.isViewActive else { return }
                self.loadHistoricalData()
            } catch {
                // Ignore sync error: keep existing data
            }
        }
    }
}

// MARK: - Async Bridging
private extension MeasurementDetailsPresenter {
    func readMeasurements(after date: Date, sampling: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        try await ruuviStorage.read(ruuviTag.id, after: date, with: sampling)
    }

    func readDownsampledMeasurements(after date: Date, intervalMinutes: Int, pick: Int) async throws -> [RuuviTagSensorRecord] {
        try await ruuviStorage
            .readDownsampled(
                ruuviTag.id,
                after: date,
                with: intervalMinutes,
                pick: Double(pick)
            )
    }

    func readLastMeasurements(from timestamp: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        try await ruuviStorage.readLast(ruuviTag.id, from: timestamp)
    }

    @discardableResult
    func syncCloud(sensor: RuuviTagSensor) async throws -> Bool {
        _ = try await cloudSyncService.sync(sensor: sensor)
        return true
    }
}

// swiftlint:enable file_length
