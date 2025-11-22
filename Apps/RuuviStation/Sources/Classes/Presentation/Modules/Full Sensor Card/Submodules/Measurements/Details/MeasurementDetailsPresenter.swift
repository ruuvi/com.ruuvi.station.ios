// swiftlint:disable file_length

import Foundation
import Humidity
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
        let op = ruuviStorage.read(
            ruuviTag.id,
            after: date,
            with: TimeInterval(2)
        )

        op.on(success: { [weak self] results in
            self?.handleDataLoaded(results.map(\.measurement))
        }, failure: { [weak self] _ in
            self?.handleDataLoadError()
        }, completion: {
            completion?()
        })
    }

    func loadWithDownsamplingCheck(from date: Date, completion: (() -> Void)? = nil) {

        let checkOp = ruuviStorage.read(
            ruuviTag.id,
            after: date,
            with: TimeInterval(2)
        )

        checkOp.on(success: { [weak self] results in
            guard let self = self else {
                completion?()
                return
            }

            if results.count < self.minimumDownsampleThreshold {
                self.handleDataLoaded(results.map(\.measurement))
                completion?()
            } else {
                self.loadDownsampledData(from: date, completion: completion)
            }
        }, failure: { [weak self] _ in
            self?.handleDataLoadError()
            completion?()
        })
    }

    func loadDownsampledData(from date: Date, completion: (() -> Void)? = nil) {
        let op = ruuviStorage.readDownsampled(
            ruuviTag.id,
            after: date,
            with: highDensityIntervalMinutes,
            pick: maximumPointsCount
        )

        op.on(success: { [weak self] results in
            self?.handleDataLoaded(results.map(\.measurement))
        }, failure: { [weak self] _ in
            self?.handleDataLoadError()
        }, completion: {
            completion?()
        })
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

        let op = ruuviStorage.readLast(
            ruuviTag.id,
            from: lastDate.timeIntervalSince1970
        )

        op.on(success: { [weak self] results in
            guard let self = self else { return }

            // Filter out duplicates and only add truly new measurements
            let newMeasurements = results
                .map(\.measurement)
                .filter { measurement in
                    measurement.date > lastDate
                }
                .sorted { $0.date < $1.date }

            guard !newMeasurements.isEmpty else { return }

            self.appendNewMeasurements(newMeasurements)
        })
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
            chartValue(for: measurement, variant: variant) != nil
        }

        guard hasValidData else {
            view?.setNoDataLabelVisibility(show: true)
            return
        }

        // Build chart entries
        var entries: [ChartDataEntry] = []
        for measurement in measurements {
            if let value = chartValue(for: measurement, variant: variant),
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
            if let value = chartValue(for: measurement, variant: variant),
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

        let isAlertOn = isAlertEnabled(for: measurementType, sensor: sensor.any)
        let upperAlert = isAlertOn ? getUpperAlert(for: measurementType, sensor: sensor.any) : nil
        let lowerAlert = isAlertOn ? getLowerAlert(for: measurementType, sensor: sensor.any) : nil

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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func chartValue(
        for measurement: RuuviMeasurement,
        variant: MeasurementDisplayVariant
    ) -> Double? {
        if variant.type.isSameCase(as: .temperature) {
            guard let temp = measurement.temperature?.plus(sensorSettings: sensorSettings) else {
                return nil
            }
            let unit = variant.resolvedTemperatureUnit(default: settings.temperatureUnit.unitTemperature)
            return temp.converted(to: unit).value
        }

        if variant.type.isSameCase(as: .humidity) {
            guard
                let humidity = measurement.humidity?.plus(sensorSettings: sensorSettings),
                let temperature = measurement.temperature?.plus(sensorSettings: sensorSettings)
            else {
                return nil
            }

            let base = Humidity(value: humidity.value, unit: .relative(temperature: temperature))
            switch variant.resolvedHumidityUnit(default: settings.humidityUnit) {
            case .percent:
                return base.value * 100
            case .gm3:
                return base.converted(to: .absolute).value
            case .dew:
                guard let dew = try? base.dewPoint(temperature: temperature) else { return nil }
                let tempUnit = variant.resolvedTemperatureUnit(default: settings.temperatureUnit.unitTemperature)
                return dew.converted(to: tempUnit).value
            }
        }

        if variant.type.isSameCase(as: .pressure) {
            guard let pressure = measurement.pressure?.plus(sensorSettings: sensorSettings) else {
                return nil
            }
            let pressureUnit = variant.resolvedPressureUnit(default: settings.pressureUnit)
            return pressure.converted(to: pressureUnit).value
        }

        switch variant.type {
        case .aqi:
            let (aqi, _, _) = measurementService.aqi(for: measurement.co2, pm25: measurement.pm25)
            return Double(aqi)
        case .co2:
            return measurementService.double(for: measurement.co2)
        case .pm10:
            return measurementService.double(for: measurement.pm1)
        case .pm25:
            return measurementService.double(for: measurement.pm25)
        case .pm40:
            return measurementService.double(for: measurement.pm4)
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
        case .soundPeak:
            return measurementService.double(for: measurement.soundPeak)
        case .soundAverage:
            return measurementService.double(for: measurement.soundAvg)
        case .voltage:
            return measurementService.double(for: measurement.voltage)
        case .rssi:
            return measurement.rssi.map(Double.init)
        case .accelerationX:
            return measurement.acceleration?.x.converted(to: .gravity).value
        case .accelerationY:
            return measurement.acceleration?.y.converted(to: .gravity).value
        case .accelerationZ:
            return measurement.acceleration?.z.converted(to: .gravity).value
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
        case .pm10:
            return alertService.isOn(type: .pMatter1(lower: 0, upper: 0), for: sensor)
        case .pm25:
            return alertService.isOn(type: .pMatter25(lower: 0, upper: 0), for: sensor)
        case .pm40:
            return alertService.isOn(type: .pMatter4(lower: 0, upper: 0), for: sensor)
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
        case .rssi:
            return alertService.isOn(type: .signal(lower: 0, upper: 0), for: sensor)
        default:
            return false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func getUpperAlert(for type: MeasurementType, sensor: AnyRuuviTagSensor) -> Double? {
        let variant = resolvedVariant
        switch type {
        case .temperature:
            return alertService.upperCelsius(for: sensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map {
                    $0.converted(
                        to: variant.resolvedTemperatureUnit(default: settings.temperatureUnit.unitTemperature)
                    ).value
                }
        case .humidity:
            let targetUnit = variant.resolvedHumidityUnit(default: settings.humidityUnit)
            guard targetUnit == .percent else { return nil }
            return alertService.upperRelativeHumidity(for: sensor).map { $0 * 100 }
        case .pressure:
            return alertService.upperPressure(for: sensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map {
                    $0.converted(
                        to: variant.resolvedPressureUnit(default: settings.pressureUnit)
                    ).value
                }
        case .co2:
            return alertService.upperCarbonDioxide(for: sensor)
        case .aqi:
            return alertService.upperAQI(for: sensor)
        case .pm10:
            return alertService.upperPM1(for: sensor)
        case .pm25:
            return alertService.upperPM25(for: sensor)
        case .pm40:
            return alertService.upperPM4(for: sensor)
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
        case .rssi:
            return alertService.upperSignal(for: sensor)
        default:
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func getLowerAlert(for type: MeasurementType, sensor: AnyRuuviTagSensor) -> Double? {
        let variant = resolvedVariant
        switch type {
        case .temperature:
            return alertService.lowerCelsius(for: sensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map {
                    $0.converted(
                        to: variant.resolvedTemperatureUnit(default: settings.temperatureUnit.unitTemperature)
                    ).value
                }
        case .humidity:
            let targetUnit = variant.resolvedHumidityUnit(default: settings.humidityUnit)
            guard targetUnit == .percent else { return nil }
            return alertService.lowerRelativeHumidity(for: sensor).map { $0 * 100 }
        case .pressure:
            return alertService.lowerPressure(for: sensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map {
                    $0.converted(
                        to: variant.resolvedPressureUnit(default: settings.pressureUnit)
                    ).value
                }
        case .co2:
            return alertService.lowerCarbonDioxide(for: sensor)
        case .aqi:
            return alertService.lowerAQI(for: sensor)
        case .pm10:
            return alertService.lowerPM1(for: sensor)
        case .pm25:
            return alertService.lowerPM25(for: sensor)
        case .pm40:
            return alertService.lowerPM4(for: sensor)
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
        case .rssi:
            return alertService.lowerSignal(for: sensor)
        default:
            return nil
        }
    }
}

// MARK: - Observers

private extension MeasurementDetailsPresenter {

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
        guard let visibility = snapshot?.metadata.measurementVisibility,
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
        let op = cloudSyncService.sync(sensor: ruuviTag)
        op.on(success: { [weak self] _ in
            guard self?.isViewActive == true else { return }
            // Reload data after sync completes
            self?.loadHistoricalData()
        })
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
        guard let visibility = snapshot?.metadata.measurementVisibility else {
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
