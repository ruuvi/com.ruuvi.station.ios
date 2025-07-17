// swiftlint:disable file_length

import Foundation
import BTKit
import DGCharts
import Future
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviReactor
import RuuviService
import RuuviStorage

// MARK: - Graph Data Service Protocol

protocol RuuviTagGraphDataService {
    var delegate: RuuviTagGraphDataServiceDelegate? { get set }

    // Main service methods
    func startObserving(snapshot: RuuviTagCardSnapshot)
    func stopObserving()
    func restartObserving()

    // Data access methods
    func getCurrentMeasurements() -> [RuuviMeasurement]
    func getChartData() -> [TagChartViewData]
    func getEnabledMeasurementTypes() -> [MeasurementType]
    func getLastMeasurement() -> RuuviMeasurement?
    func getSensorSettings() -> SensorSettings?

    // Settings and configuration
    func updateSensorSettings(_ settings: SensorSettings?)
    func updateChartShowMinMaxAvgSetting(with show: Bool)

    // Export and sync functionality
    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError>
    func stopSyncRecords() -> Future<Bool, RUError>
    func isSyncingRecords() -> Bool
    func deleteAllRecords() -> Future<Void, RUError>
}

// MARK: - Graph Data Service Delegate

protocol RuuviTagGraphDataServiceDelegate: AnyObject {
    func graphDataService(
        _ service: RuuviTagGraphDataService,
        didUpdateChartData chartData: [TagChartViewData]
    )
    func graphDataService(
        _ service: RuuviTagGraphDataService,
        didInsertNewMeasurements newMeasurements: [RuuviMeasurement]
    )
    func graphDataService(
        _ service: RuuviTagGraphDataService,
        didCreateChartModules modules: [MeasurementType]
    )
    func graphDataService(
        _ service: RuuviTagGraphDataService,
        didUpdateSensor sensor: AnyRuuviTagSensor
    )
    func graphDataService(
        _ service: RuuviTagGraphDataService,
        didEncounterError error: RUError
    )
}

// MARK: - Graph Data Service Implementation

final class RuuviTagGraphDataServiceImpl: RuuviTagGraphDataService {

    // MARK: - Properties
    weak var delegate: RuuviTagGraphDataServiceDelegate?

    // MARK: - Services
    private let ruuviStorage: RuuviStorage
    private let ruuviReactor: RuuviReactor
    private let ruuviPool: RuuviPool
    private let settings: RuuviLocalSettings
    private let measurementService: RuuviServiceMeasurement
    private let tagDataService: RuuviTagDataService
    private let alertService: RuuviServiceAlert
    private let gattService: GATTService
    private let exportService: RuuviServiceExport
    private let cloudSyncService: RuuviServiceCloudSync
    private let ruuviSensorRecords: RuuviServiceSensorRecords
    private let featureToggleService: FeatureToggleService
    private let localSyncState: RuuviLocalSyncState
    private let ruuviAppSettingsService: RuuviServiceAppSettings

    // MARK: - State
    private var currentSnapshot: RuuviTagCardSnapshot?
    private var ruuviTagSensor: AnyRuuviTagSensor?
    private var sensorSettings: SensorSettings?
    private var ruuviTagData: [RuuviMeasurement] = []
    private var lastMeasurement: RuuviMeasurement?
    private var lastMeasurementRecord: RuuviTagSensorRecord?
    private var chartModules: [MeasurementType] = []
    private var datasource: [TagChartViewData] = []

    // MARK: - Observation Tokens
    private var ruuviTagSensorObservationToken: RuuviReactorToken?
    private var sensorSettingsToken: RuuviReactorToken?
    private var timer: Timer?

    // MARK: - Constants
    private let highDensityIntervalMinutes: Int = 15
    private let maximumPointsCount: Double = 3000.0
    private let minimumDownsampleThreshold: Int = 1000
    private var gattSyncInterruptedByUser: Bool = false

    // MARK: - Initialization
    init(
        ruuviStorage: RuuviStorage,
        ruuviReactor: RuuviReactor,
        ruuviPool: RuuviPool,
        settings: RuuviLocalSettings,
        measurementService: RuuviServiceMeasurement,
        tagDataService: RuuviTagDataService,
        alertService: RuuviServiceAlert,
        gattService: GATTService,
        exportService: RuuviServiceExport,
        cloudSyncService: RuuviServiceCloudSync,
        ruuviSensorRecords: RuuviServiceSensorRecords,
        featureToggleService: FeatureToggleService,
        localSyncState: RuuviLocalSyncState,
        ruuviAppSettingsService: RuuviServiceAppSettings
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviReactor = ruuviReactor
        self.ruuviPool = ruuviPool
        self.settings = settings
        self.measurementService = measurementService
        self.tagDataService = tagDataService
        self.alertService = alertService
        self.gattService = gattService
        self.exportService = exportService
        self.cloudSyncService = cloudSyncService
        self.ruuviSensorRecords = ruuviSensorRecords
        self.featureToggleService = featureToggleService
        self.localSyncState = localSyncState
        self.ruuviAppSettingsService = ruuviAppSettingsService
    }

    deinit {
        stopObserving()
    }

    // MARK: - RuuviTagGraphDataService Implementation

    func startObserving(snapshot: RuuviTagCardSnapshot) {
        currentSnapshot = snapshot

        // Convert snapshot to sensor
        guard let sensor = tagDataService.getSensor(for: snapshot.id) else {
            return
        }

        ruuviTagSensor = sensor

        // Get sensor settings
        sensorSettings = tagDataService.getSensorSettings(for: snapshot.id)

        // Start observations and data loading
        restartObservingTags()
        startObservingSensorSettings()
        restartScheduler()
        fetchLast()
        syncFullHistory(for: sensor)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchPoints { [weak self] in
                guard let self = self, let sensor = self.ruuviTagSensor else { return }
                DispatchQueue.main.async {
                    self.delegate?.graphDataService(self, didUpdateSensor: sensor)
                }
            }
        }
    }

    func stopObserving() {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
        sensorSettingsToken?.invalidate()
        sensorSettingsToken = nil
        timer?.invalidate()
        timer = nil
    }

    func restartObserving() {
        guard let snapshot = currentSnapshot else { return }
        stopObserving()
        ruuviTagData.removeAll()
        startObserving(snapshot: snapshot)
    }

    func getCurrentMeasurements() -> [RuuviMeasurement] {
        return ruuviTagData
    }

    func getChartData() -> [TagChartViewData] {
        return datasource
    }

    func getEnabledMeasurementTypes() -> [MeasurementType] {
        return chartModules
    }

    func getLastMeasurement() -> RuuviMeasurement? {
        return lastMeasurement
    }

    func getSensorSettings() -> SensorSettings? {
        return sensorSettings
    }

    func updateSensorSettings(_ settings: SensorSettings?) {
        sensorSettings = settings
    }

    func updateChartShowMinMaxAvgSetting(with show: Bool) {
        ruuviAppSettingsService.set(showMinMaxAvg: show)
    }

    // MARK: - Export and Sync Methods

    func exportData() -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        guard let ruuviTagSensor = ruuviTagSensor,
              let sensorSettings = sensorSettings else {
            promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
            return promise.future
        }

        let op = exportService.csvLog(
            for: ruuviTagSensor.id,
            version: ruuviTagSensor.version,
            settings: sensorSettings
        )
        op.on(success: { url in
            promise.succeed(value: url)
        }, failure: { error in
            promise.fail(error: .ruuviService(error))
        })
        return promise.future
    }

    func isSyncingRecords() -> Bool {
        guard let luid = ruuviTagSensor?.luid else { return false }
        return gattService.isSyncingLogs(with: luid.value)
    }

    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        guard let ruuviTagSensor = ruuviTagSensor,
              let luid = ruuviTagSensor.luid else {
            promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
            return promise.future
        }

        let connectionTimeout: TimeInterval = settings.connectionTimeout
        let serviceTimeout: TimeInterval = settings.serviceTimeout
        var syncFrom = localSyncState.getGattSyncDate(for: ruuviTagSensor.macId)
        let historyLength = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.dataPruningOffsetHours,
            to: Date()
        )
        if syncFrom == nil {
            syncFrom = historyLength
        } else if let from = syncFrom,
                  let history = historyLength,
                  from < history {
            syncFrom = history
        }

        let op = gattService.syncLogs(
            uuid: luid.value,
            mac: ruuviTagSensor.macId?.value,
            firmware: ruuviTagSensor.version,
            from: syncFrom ?? Date.distantPast,
            settings: sensorSettings,
            progress: progress,
            connectionTimeout: connectionTimeout,
            serviceTimeout: serviceTimeout
        )
        op.on(success: { [weak self] _ in
            if let isInterrupted = self?.gattSyncInterruptedByUser, !isInterrupted {
                self?.localSyncState.setGattSyncDate(Date(), for: self?.ruuviTagSensor?.macId)
            }
            self?.gattSyncInterruptedByUser = false
            promise.succeed(value: ())
        }, failure: { error in
            promise.fail(error: .ruuviService(error))
        })
        return promise.future
    }

    func stopSyncRecords() -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        guard let luid = ruuviTagSensor?.luid else {
            promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
            return promise.future
        }
        let op = gattService.stopGattSync(for: luid.value)
        op.on(success: { [weak self] response in
            self?.gattSyncInterruptedByUser = true
            promise.succeed(value: response)
        }, failure: { error in
            promise.fail(error: .ruuviService(error))
        })
        return promise.future
    }

    func deleteAllRecords() -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        guard let sensor = ruuviTagSensor else {
            promise.fail(error: .unexpected(.failedToFindRuuviTag))
            return promise.future
        }

        ruuviSensorRecords.clear(for: sensor)
            .on(failure: { error in
                promise.fail(error: .ruuviService(error))
            }, completion: { [weak self] in
                self?.localSyncState.setSyncDate(nil, for: self?.ruuviTagSensor?.macId)
                self?.localSyncState.setSyncDate(nil)
                self?.localSyncState.setGattSyncDate(nil, for: self?.ruuviTagSensor?.macId)
                self?.restartObserving()
                promise.succeed(value: ())
            })
        return promise.future
    }
}

// MARK: - Private Methods

private extension RuuviTagGraphDataServiceImpl {

    // MARK: - Data Observation Methods

    func restartObservingTags() {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = ruuviReactor.observe { [weak self] change in
            switch change {
            case let .initial(sensors):
                if let id = self?.ruuviTagSensor?.id,
                   let sensor = sensors.first(where: { $0.id == id }) {
                    self?.ruuviTagSensor = sensor
                }
            case let .update(sensor):
                if self?.ruuviTagSensor?.id == sensor.id {
                    self?.ruuviTagSensor = sensor
                    self?.delegate?.graphDataService(self!, didUpdateSensor: sensor)
                }
            default:
                return
            }
        }
    }

    func startObservingSensorSettings() {
//        guard let sensor = ruuviTagSensor else { return }
//
//        sensorSettingsToken?.invalidate()
//        sensorSettingsToken = ruuviReactor.observe(sensor) { [weak self] change in
//            switch change {
//            case let .initial(sensorSettings):
////                self?.sensorSettings = sensorSettings
////                self?.updateSensorSettings(sensorSettings)
//            case let .update(sensorSettings):
//                self?.sensorSettings = sensorSettings
//                self?.updateSensorSettings(sensorSettings)
//                // Recreate chart data when sensor settings change
//                self?.createChartData()
//            case .delete:
//                self?.sensorSettings = nil
//            default:
//                break
//            }
//        }
    }

    func restartScheduler() {
        let timerInterval = settings.appIsOnForeground ? 2 : settings.chartIntervalSeconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(timerInterval),
            repeats: true,
            block: { [weak self] _ in
                self?.fetchLastFromDate()
                self?.removeFirst()
            }
        )
    }

    func removeFirst() {
        guard settings.chartShowAllMeasurements else { return }
        let cropDate = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.dataPruningOffsetHours,
            to: Date()
        ) ?? Date.distantPast
        let prunedResults = ruuviTagData.filter { $0.date < cropDate }
        ruuviTagData.removeFirst(prunedResults.count)
    }

    // MARK: - Data Fetching Methods

    func fetchLast() {
        guard let ruuviTagSensor = ruuviTagSensor else { return }

        let op = ruuviStorage.readLatest(ruuviTagSensor)
        op.on(success: { [weak self] record in
            guard let self = self else { return }
            guard let record = record else {
                self.delegate?.graphDataService(self, didCreateChartModules: [])
                return
            }

            self.lastMeasurement = record.measurement
            self.lastMeasurementRecord = record

            var chartsCases = MeasurementType.chartsCases
            if record.temperature == nil {
                chartsCases.removeAll { $0 == .temperature }
            }
            if record.humidity == nil {
                chartsCases.removeAll { $0 == .humidity }
            }
            if record.pressure == nil {
                chartsCases.removeAll { $0 == .pressure }
            }
            if record.co2 == nil && record.pm25 == nil {
                chartsCases.removeAll { $0 == .aqi }
            }
            if record.co2 == nil {
                chartsCases.removeAll { $0 == .co2 }
            }
            if record.pm25 == nil {
                chartsCases.removeAll { $0 == .pm25 }
            }
            if record.voc == nil {
                chartsCases.removeAll { $0 == .voc }
            }
            if record.nox == nil {
                chartsCases.removeAll { $0 == .nox }
            }
            if record.luminance == nil {
                chartsCases.removeAll { $0 == .luminosity }
            }
            if record.dbaInstant == nil {
                chartsCases.removeAll { $0 == .soundInstant }
            }

            self.chartModules = chartsCases
            self.delegate?.graphDataService(self, didCreateChartModules: chartsCases)
        }, failure: { [weak self] error in
            guard let self = self else { return }
            self.delegate?.graphDataService(self, didEncounterError: .ruuviStorage(error))
        })
    }

    func fetchLastFromDate() {
        guard let lastMeasurement = lastMeasurement,
              let ruuviTagSensor = ruuviTagSensor else { return }

        let op = ruuviStorage.readLast(
            ruuviTagSensor.id,
            from: lastMeasurement.date.timeIntervalSince1970
        )
        op.on(success: { [weak self] results in
            guard let self = self else { return }
            guard results.count > 0, let last = results.last else {
                return
            }

            self.lastMeasurement = last.measurement
            self.lastMeasurementRecord = last
            self.ruuviTagData.append(last.measurement)

            // Process new measurement and update charts
            self.processNewMeasurements([last.measurement])
        }, failure: { [weak self] error in
            guard let self = self else { return }
            self.delegate?.graphDataService(self, didEncounterError: .ruuviStorage(error))
        })
    }

    func fetchPoints(_ completion: (() -> Void)? = nil) {
        if settings.chartShowAllMeasurements {
            fetchAll(completion)
        } else {
            fetchAll { [weak self] in
                guard let self = self else { return }
                if self.ruuviTagData.count < self.minimumDownsampleThreshold {
                    completion?()
                } else {
                    self.fetchDownSampled(completion)
                }
            }
        }
    }

    func fetchAll(_ completion: (() -> Void)? = nil) {
        guard let ruuviTagSensor = ruuviTagSensor else { return }

        let date = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.chartDurationHours,
            to: Date()
        ) ?? Date.distantPast

        let op = ruuviStorage.read(
            ruuviTagSensor.id,
            after: date,
            with: TimeInterval(2)
        )
        op.on(success: { [weak self] results in
            self?.ruuviTagData = results.map(\.measurement)
            // Create chart data after fetching
            self?.createChartData()
        }, failure: { [weak self] error in
            guard let self = self else { return }
            self.delegate?.graphDataService(self, didEncounterError: .ruuviStorage(error))
        }, completion: completion)
    }

    func fetchDownSampled(_ completion: (() -> Void)? = nil) {
        guard let ruuviTagSensor = ruuviTagSensor else { return }

        let date = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.chartDurationHours,
            to: Date()
        ) ?? Date.distantPast

        let op = ruuviStorage.readDownsampled(
            ruuviTagSensor.id,
            after: date,
            with: highDensityIntervalMinutes,
            pick: maximumPointsCount
        )
        op.on(success: { [weak self] results in
            self?.ruuviTagData = results.map(\.measurement)
            // Create chart data after fetching
            self?.createChartData()
        }, failure: { [weak self] error in
            guard let self = self else { return }
            self.delegate?.graphDataService(self, didEncounterError: .ruuviStorage(error))
        }, completion: completion)
    }

    func syncFullHistory(for ruuviTag: RuuviTagSensor) {
        if ruuviTag.isCloud && settings.historySyncForEachSensor {
            ruuviStorage.readLatest(ruuviTag).on(success: { [weak self] record in
                if record != nil {
                    self?.cloudSyncService.sync(sensor: ruuviTag).on(success: { [weak self] _ in
                        self?.restartScheduler()
                    })
                }
            })
        }
    }

    // MARK: - Chart Data Processing

    func processNewMeasurements(_ newMeasurements: [RuuviMeasurement]) {
        // Create chart data and notify delegate
        createChartData()
        delegate?.graphDataService(self, didInsertNewMeasurements: newMeasurements)
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func createChartData() {
        guard let ruuviTag = ruuviTagSensor else { return }
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
            // Humidity
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
            if let luminosityEntry = chartEntry(for: measurement, type: .luminosity) {
                luminosityData.append(luminosityEntry)
            }
            // Sound
            if let soundEntry = chartEntry(for: measurement, type: .soundInstant) {
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

        // Notify delegate with processed chart data
        delegate?.graphDataService(self, didUpdateChartData: datasource)
    }

    // MARK: - Chart Entry Creation

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func chartEntry(for data: RuuviMeasurement, type: MeasurementType) -> ChartDataEntry? {
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
            let value = measurementService.aqi(for: data.co2, pm25: data.pm25)
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
        case .co2:
            let value = measurementService.double(for: data.co2)
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
        case .pm25:
            let value = measurementService.double(for: data.pm25)
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
        case .pm10:
            let value = measurementService.double(for: data.pm10)
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
        case .voc:
            let value = measurementService.double(for: data.voc)
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
        case .nox:
            let value = measurementService.double(for: data.nox)
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
        case .luminosity:
            let value = measurementService.double(for: data.luminosity)
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
        case .soundInstant:
            let value = measurementService.double(for: data.soundInstant)
            return ChartDataEntry(x: data.date.timeIntervalSince1970, y: value)
        default:
            fatalError("before need implement chart with current type!")
        }

        guard let y = value else { return nil }
        return ChartDataEntry(x: data.date.timeIntervalSince1970, y: y)
    }
}
// swiftlint:enable file_length
