// swiftlint:disable file_length
import BTKit
import Foundation
import Future
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviReactor
import RuuviService
import RuuviStorage
//import Combine

/// Interactor for handling sensor data and charts for the new cards UI
class NewCardsInteractor {
    // MARK: - Public Properties

    weak var presenter: NewCardsInteractorOutput!

    // Dependencies - should use a dependency injector in a larger refactoring
    var gattService: GATTService!
    var ruuviPool: RuuviPool!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
    var cloudSyncService: RuuviServiceCloudSync!
    var flags: RuuviLocalFlags!
    var settings: RuuviLocalSettings!
    var exportService: RuuviServiceExport!
    var ruuviSensorRecords: RuuviServiceSensorRecords!
    var featureToggleService: FeatureToggleService!
    var localSyncState: RuuviLocalSyncState!
    var ruuviAppSettingsService: RuuviServiceAppSettings!

    // Sensor data
    var ruuviTagSensor: AnyRuuviTagSensor!
    var sensorSettings: SensorSettings?
    var lastMeasurement: RuuviMeasurement?
    var lastMeasurementRecord: RuuviTagSensorRecord?
    var ruuviTagData: [RuuviMeasurement] = []

    // MARK: - Private Properties

    private var ruuviTagSensorObservationToken: RuuviReactorToken?
    private var dataFetchTimer: Timer?
    private var sensors: [AnyRuuviTagSensor] = []
//    private var cancellables = Set<AnyCancellable>()
    private var isFetchingData = false
    private var cloudSyncingSensors: [String: Bool] = [:] // Track sync status by sensor ID

    // Constants
    private let highDensityIntervalMinutes: Int = 15
    private let maximumPointsCount: Double = 3000.0
    private let minimumDownsampleThreshold: Int = 1000
    private var gattSyncInterruptedByUser: Bool = false

    // MARK: - Initialization & Deinitialization

    deinit {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
        dataFetchTimer?.invalidate()
        dataFetchTimer = nil
//        cancellables.removeAll()
        cloudSyncingSensors.removeAll()
    }
}

// MARK: - NewCardsInteractorInput

extension NewCardsInteractor: NewCardsInteractorInput {
    /// Starts observing changes in the Ruuvi tags
    func restartObservingTags() {
        stopObservingTags()

        ruuviTagSensorObservationToken = ruuviReactor.observe { [weak self] change in
            guard let self = self else { return }

            switch change {
            case let .initial(sensors):
                self.sensors = sensors
                if let id = self.ruuviTagSensor?.id,
                   let sensor = sensors.first(where: { $0.id == id }) {
                    self.ruuviTagSensor = sensor
                }

            case let .insert(sensor):
                self.sensors.append(sensor)

            case let .update(sensor):
                if self.ruuviTagSensor?.id == sensor.id,
                   let index = self.sensors.firstIndex(where: { $0.id == sensor.id }) {
                    self.ruuviTagSensor = sensor
                    self.sensors[index] = sensor
                    self.presenter.interactorDidUpdate(sensor: sensor)
                }

            case .delete, .error:
                // Handle deletion or error if needed
                break
            }
        }
    }

    /// Stops observing changes in Ruuvi tags
    func stopObservingTags() {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
    }

    /// Configures the interactor with a specific tag and settings
    func configure(
        withTag ruuviTag: AnyRuuviTagSensor,
        andSettings settings: SensorSettings?
    ) {
        // Clear state from previous sensor
        clearCurrentState()

        ruuviTagSensor = ruuviTag
        sensorSettings = settings

        restartScheduler()
        fetchLatestMeasurement()

        // First fetch the current data
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchPoints { [weak self] in
                guard let self = self, let sensor = self.ruuviTagSensor else { return }

                // Update UI with current data
                self.presenter.interactorDidUpdate(sensor: sensor)

                // Then sync cloud data if applicable
                if let tagSensor = sensor as? RuuviTagSensor,
                   tagSensor.isCloud && self.flags.historySyncForEachSensor {

                    // Check if this specific sensor is already syncing
                    if self.cloudSyncingSensors[tagSensor.id] != true {
                        // Mark this sensor as syncing
                        self.cloudSyncingSensors[tagSensor.id] = true

                        self.cloudSyncService.sync(sensor: tagSensor)
                            .on(success: { [weak self] _ in
                                guard let self = self else { return }

                                // After sync, refresh data again
                                self.ruuviTagData.removeAll()
                                self.fetchPoints { [weak self] in
                                    guard let self = self, let currentSensor = self.ruuviTagSensor else {
                                        // Clear syncing flag even if the rest fails
                                        self?.cloudSyncingSensors[tagSensor.id] = false
                                        return
                                    }

                                    // Update UI with synced data
                                    self.presenter.interactorDidUpdate(sensor: currentSensor)
                                    self.fetchLatestMeasurement()

                                    // Clear syncing status for this sensor
                                    self.cloudSyncingSensors[tagSensor.id] = false
                                }
                            }, failure: { [weak self] _ in
                                // Clear syncing status on failure
                                self?.cloudSyncingSensors[tagSensor.id] = false
                            })
                    }
                }
            }
        }
    }

    /// Updates the sensor settings
    func updateSensorSettings(settings: SensorSettings?) {
        sensorSettings = settings
    }

    /// Restarts data observation and reloads charts
    func restartObservingData() {
        ruuviTagData.removeAll()

        fetchPoints { [weak self] in
            guard let self = self else { return }
            self.restartScheduler()

            // If we still have no data, try to sync
            if self.ruuviTagData.isEmpty {
                self.ensureDataAvailable()
            } else {
                self.reloadCharts()
            }
        }
    }

    /// Stops observing Ruuvi tag data
    func stopObservingRuuviTagsData() {
        dataFetchTimer?.invalidate()
        dataFetchTimer = nil
    }

    /// Exports data to CSV
    func export() -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()

        guard let sensor = ruuviTagSensor, let sensorSettings = sensorSettings else {
//            promise.fail(error: .unexpected(.))
            return promise.future
        }

        let operation = exportService.csvLog(
            for: sensor.id,
            version: sensor.version,
            settings: sensorSettings
        )

        operation.on(
            success: { url in
                promise.succeed(value: url)
            },
            failure: { error in
                promise.fail(error: .ruuviService(error))
            }
        )

        return promise.future
    }

    /// Checks if the sensor is currently syncing records
    func isSyncingRecords() -> Bool {
        guard let luid = ruuviTagSensor?.luid else {
            return false
        }

        return gattService.isSyncingLogs(with: luid.value)
    }

    /// Syncs records with progress reporting
    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()

        guard let sensor = ruuviTagSensor, let luid = sensor.luid else {
            promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
            return promise.future
        }

        let connectionTimeout: TimeInterval = settings.connectionTimeout
        let serviceTimeout: TimeInterval = settings.serviceTimeout

        // Determine sync date
        var syncFrom = localSyncState.getGattSyncDate(for: sensor.macId)
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

        let operation = gattService.syncLogs(
            uuid: luid.value,
            mac: sensor.macId?.value,
            firmware: sensor.version,
            from: syncFrom ?? Date.distantPast,
            settings: sensorSettings,
            progress: progress,
            connectionTimeout: connectionTimeout,
            serviceTimeout: serviceTimeout
        )

        operation.on(
            success: { [weak self] _ in
                guard let self = self else {
                    promise.succeed(value: ())
                    return
                }

                if !self.gattSyncInterruptedByUser {
                    self.localSyncState.setGattSyncDate(Date(), for: self.ruuviTagSensor.macId)
                }

                self.gattSyncInterruptedByUser = false

                // After GATT sync, refresh the data
                self.fetchPoints { [weak self] in
                    guard let self = self, let sensor = self.ruuviTagSensor else {
                        promise.succeed(value: ())
                        return
                    }

                    self.presenter.interactorDidUpdate(sensor: sensor)
                    promise.succeed(value: ())
                }
            },
            failure: { error in
                promise.fail(error: .ruuviService(error))
            }
        )

        return promise.future
    }

    /// Stops syncing records
    func stopSyncRecords() -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()

        guard let sensor = ruuviTagSensor, let luid = sensor.luid else {
            promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
            return promise.future
        }

        let operation = gattService.stopGattSync(for: luid.value)

        operation.on(
            success: { [weak self] response in
                self?.gattSyncInterruptedByUser = true
                promise.succeed(value: response)
            },
            failure: { error in
                promise.fail(error: .ruuviService(error))
            }
        )

        return promise.future
    }

    /// Deletes all records for a sensor
    func deleteAllRecords(for sensor: RuuviTagSensor) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()

        ruuviSensorRecords.clear(for: sensor)
            .on(
                failure: { error in
                    promise.fail(error: .ruuviService(error))
                },
                completion: { [weak self] in
                    guard let self = self else {
                        promise.succeed(value: ())
                        return
                    }

                    // Reset sync dates
                    self.localSyncState.setSyncDate(nil, for: self.ruuviTagSensor.macId)
                    self.localSyncState.setSyncDate(nil)
                    self.localSyncState.setGattSyncDate(nil, for: self.ruuviTagSensor.macId)

                    // Reload data
                    self.restartObservingData()
                    promise.succeed(value: ())
                }
            )

        return promise.future
    }

    /// Updates the settings for showing min/max/avg on charts
    func updateChartShowMinMaxAvgSetting(with show: Bool) {
        ruuviAppSettingsService.set(showMinMaxAvg: show)
    }

    /// Syncs data from cloud and refreshes the charts
    func syncAndRefresh() -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()

        guard let sensor = ruuviTagSensor, sensor.isCloud else {
//            promise.fail(error: .unexpected(.noSensor))
            return promise.future
        }

        // Check if this specific sensor is already syncing
        if cloudSyncingSensors[sensor.id] == true {
            promise.succeed(value: ())
            return promise.future
        }

        // Mark this sensor as syncing
        cloudSyncingSensors[sensor.id] = true

        cloudSyncService.sync(sensor: sensor)
            .on(success: { [weak self] _ in
                guard let self = self else {
                    promise.succeed(value: ())
                    return
                }

                // Reload data after sync completes
                self.ruuviTagData.removeAll()

                self.fetchPoints { [weak self] in
                    guard let self = self, let sensor = self.ruuviTagSensor else {
                        // Clear syncing status even if self is nil
                        if let sensorId = sensor.macId?.mac {
                            self?.cloudSyncingSensors[sensorId] = false
                        }
                        promise.succeed(value: ())
                        return
                    }

                    // Update the UI with new data
                    self.presenter.interactorDidUpdate(sensor: sensor)
                    self.fetchLatestMeasurement()

                    // Clear syncing status for this sensor
                    self.cloudSyncingSensors[sensor.id] = false
                    promise.succeed(value: ())
                }
            }, failure: { [weak self] error in
                guard let self = self, let sensor = self.ruuviTagSensor else {
                    promise.fail(error: .ruuviService(error))
                    return
                }

                // Clear syncing status for this sensor
                self.cloudSyncingSensors[sensor.id] = false
                promise.fail(error: .ruuviService(error))
            })

        return promise.future
    }

    /// Checks if we have data and triggers sync if needed
    func ensureDataAvailable() {
        guard let sensor = ruuviTagSensor as? RuuviTagSensor,
              sensor.isCloud && flags.historySyncForEachSensor else {
            return
        }

        // If we have no data, try to sync
        if ruuviTagData.isEmpty && cloudSyncingSensors[sensor.id] != true {
            fetchLatestMeasurement()

            // If still no data after fetching local, try cloud sync
            if ruuviTagData.isEmpty {
                syncAndRefresh().on(success: { [weak self] _ in
                    // After successful sync, make sure UI is updated
                    guard let self = self, let sensor = self.ruuviTagSensor else { return }

                    // Verify if we have data now
                    if !self.ruuviTagData.isEmpty {
                        self.presenter.interactorDidUpdate(sensor: sensor)
                    }
                })
            }
        }
    }
}

// MARK: - Private Methods

extension NewCardsInteractor {
    /// Clears the current state when changing sensors
    private func clearCurrentState() {
        ruuviTagData.removeAll()
        lastMeasurement = nil
        lastMeasurementRecord = nil
    }

    /// Restarts the timer for fetching data
    private func restartScheduler() {
        // Cancel existing timer
        dataFetchTimer?.invalidate()

        // Determine timer interval based on app state
        let timerInterval = settings.appIsOnForeground ? 2 : settings.chartIntervalSeconds

        // Create new timer
        dataFetchTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(timerInterval),
            repeats: true,
            block: { [weak self] _ in
                self?.fetchLatestMeasurements()
                self?.pruneOldData()
            }
        )

        // Make sure timer runs even when scrolling
        RunLoop.current.add(dataFetchTimer!, forMode: .common)
    }

    /// Removes old data points based on settings
    private func pruneOldData() {
        guard !settings.chartDownsamplingOn else { return }

        let pruningDate = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.dataPruningOffsetHours,
            to: Date()
        ) ?? Date.distantPast

        let oldDataCount = ruuviTagData.prefix { $0.date < pruningDate }.count

        if oldDataCount > 0 {
            ruuviTagData.removeFirst(oldDataCount)
        }
    }

    /// Fetches the latest measurement for the sensor
    private func fetchLatestMeasurement() {
        guard let sensor = ruuviTagSensor else { return }

        let operation = ruuviStorage.readLatest(sensor)

        operation.on(success: { [weak self] record in
            guard let self = self, let sensor = self.ruuviTagSensor else { return }

            guard let record = record else {
                // No records available, create empty chart modules
                self.presenter.createChartModules(from: [], for: sensor)
                return
            }

            self.lastMeasurement = record.measurement
            self.lastMeasurementRecord = record

            // Determine which chart types to show based on available data
            var chartTypes = MeasurementType.chartsCases

            // Remove chart types for which we don't have data
            if record.temperature == nil {
                chartTypes.removeAll { $0 == .temperature }
            }
            if record.humidity == nil {
                chartTypes.removeAll { $0 == .humidity }
            }
            if record.pressure == nil {
                chartTypes.removeAll { $0 == .pressure }
            }
            if record.co2 == nil && record.pm2_5 == nil &&
               record.voc == nil && record.nox == nil {
                chartTypes.removeAll { $0 == .aqi }
            }
            if record.co2 == nil {
                chartTypes.removeAll { $0 == .co2 }
            }
            if record.pm2_5 == nil {
                chartTypes.removeAll { $0 == .pm25 }
            }
            if record.pm10 == nil {
                chartTypes.removeAll { $0 == .pm10 }
            }
            if record.voc == nil {
                chartTypes.removeAll { $0 == .voc }
            }
            if record.nox == nil {
                chartTypes.removeAll { $0 == .nox }
            }
            if record.luminance == nil || record.luminance == 0 {
                chartTypes.removeAll { $0 == .luminosity }
            }
            if record.dbaAvg == nil || record.dbaAvg == 0 {
                chartTypes.removeAll { $0 == .sound }
            }

            self.presenter.createChartModules(from: chartTypes, for: sensor)
            self.presenter.updateLatestRecord(record, for: sensor)
        }, failure: { [weak self] error in
            guard let self = self, let sensor = self.ruuviTagSensor else { return }
            self.presenter.interactorDidError(.ruuviStorage(error), for: sensor)
        })
    }

    /// Fetches the latest measurements since the last fetch
    private func fetchLatestMeasurements() {
        guard let sensor = ruuviTagSensor,
              let lastMeasurement = lastMeasurement,
              let lastMeasurementRecord = lastMeasurementRecord else {
            return
        }

        let operation = ruuviStorage.readLast(
            sensor.id,
            from: lastMeasurement.date.timeIntervalSince1970
        )

        operation.on(
            success: { [weak self] results in
                guard let self = self, let sensor = self.ruuviTagSensor else { return }

                guard !results.isEmpty, let lastRecord = results.last else {
                    // No new measurements, just update with the last known one
                    self.presenter.updateLatestRecord(lastMeasurementRecord, for: sensor)
                    return
                }

                // Update last measurement
                self.lastMeasurement = lastRecord.measurement
                self.lastMeasurementRecord = lastRecord

                // Add new measurements to data
                let newMeasurements = results.map(\.measurement)
                self.ruuviTagData.append(contentsOf: newMeasurements)

                // Send to presenter
                self.presenter.insertMeasurements(newMeasurements, for: sensor)
                self.presenter.updateLatestRecord(lastRecord, for: sensor)
            },
            failure: { [weak self] error in
                guard let self = self, let sensor = self.ruuviTagSensor else { return }

                // On error, at least try to update with the last known record
                if let record = self.lastMeasurementRecord {
                    self.presenter.updateLatestRecord(record, for: sensor)
                }

                self.presenter.interactorDidError(.ruuviStorage(error), for: sensor)
            }
        )
    }

    /// Fetches points for charts with optional downsampling
    private func fetchPoints(_ completion: (() -> Void)? = nil) {
        guard !isFetchingData else {
            completion?()
            return
        }

        isFetchingData = true

        if settings.chartDownsamplingOn {
            fetchAllData { [weak self] in
                guard let self = self else {
                    completion?()
                    return
                }

                if self.ruuviTagData.count < self.minimumDownsampleThreshold {
                    self.isFetchingData = false
                    completion?()
                } else {
                    self.fetchDownsampledData {
                        self.isFetchingData = false
                        completion?()
                    }
                }
            }
        } else {
            fetchAllData { [weak self] in
                self?.isFetchingData = false
                completion?()
            }
        }
    }

    /// Fetches all data points for the specified duration
    private func fetchAllData(_ completion: (() -> Void)? = nil) {
        guard let sensor = ruuviTagSensor else {
            completion?()
            return
        }

        // Calculate start date based on chart duration setting
        let startDate = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.chartDurationHours,
            to: Date()
        ) ?? Date.distantPast

        let operation = ruuviStorage.read(
            sensor.id,
            after: startDate,
            with: TimeInterval(2) // Minimum interval between points
        )

        operation.on(
            success: { [weak self] results in
                self?.ruuviTagData = results.map(\.measurement)
            },
            failure: { [weak self] error in
                guard let self = self, let sensor = self.ruuviTagSensor else { return }
                self.presenter.interactorDidError(.ruuviStorage(error), for: sensor)
            },
            completion: completion
        )
    }

    /// Fetches downsampled data for efficient chart rendering
    private func fetchDownsampledData(_ completion: (() -> Void)? = nil) {
        guard let sensor = ruuviTagSensor else {
            completion?()
            return
        }

        // Calculate start date based on chart duration setting
        let startDate = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.chartDurationHours,
            to: Date()
        ) ?? Date.distantPast

        let operation = ruuviStorage.readDownsampled(
            sensor.id,
            after: startDate,
            with: highDensityIntervalMinutes,
            pick: maximumPointsCount
        )

        operation.on(
            success: { [weak self] results in
                self?.ruuviTagData = results.map(\.measurement)
            },
            failure: { [weak self] error in
                guard let self = self, let sensor = self.ruuviTagSensor else { return }
                self.presenter.interactorDidError(.ruuviStorage(error), for: sensor)
            },
            completion: completion
        )
    }

    /// Syncs full history for a cloud-connected sensor
    private func syncFullHistory(for ruuviTag: RuuviTagSensor) {
        guard ruuviTag.isCloud && flags.historySyncForEachSensor && cloudSyncingSensors[ruuviTag.id] != true else {
            return
        }

        // Mark this sensor as syncing
        cloudSyncingSensors[ruuviTag.id] = true

        ruuviStorage.readLatest(ruuviTag).on(success: { [weak self] record in
            guard let self = self else {
                return
            }

            self.cloudSyncService.sync(sensor: ruuviTag)
                .on(success: { [weak self] _ in
                    guard let self = self, let sensor = self.ruuviTagSensor else {
                        // Clear syncing flag even if self is nil
                        self?.cloudSyncingSensors[ruuviTag.id] = false
                        return
                    }

                    // After successful cloud sync, reload all data to refresh charts
                    self.ruuviTagData.removeAll()

                    self.fetchPoints { [weak self] in
                        guard let self = self else {
                            return
                        }

                        // Make sure the scheduler is running
                        self.restartScheduler()

                        // Explicitly reload charts with new data
                        self.presenter.interactorDidUpdate(sensor: sensor)

                        // Also update the latest record
                        self.fetchLatestMeasurement()

                        // Clear syncing status for this sensor
                        self.cloudSyncingSensors[ruuviTag.id] = false
                    }
                }, failure: { [weak self] _ in
                    // Clear syncing status on failure
                    self?.cloudSyncingSensors[ruuviTag.id] = false
                })
        }, failure: { [weak self] _ in
            // Clear syncing status on failure
            self?.cloudSyncingSensors[ruuviTag.id] = false
        })
    }

    /// Sends new measurements to the presenter
    private func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        guard let sensor = ruuviTagSensor else { return }
        presenter.insertMeasurements(newValues, for: sensor)
    }

    /// Tells the presenter to reload charts
    private func reloadCharts() {
        guard let sensor = ruuviTagSensor else { return }
        presenter.interactorDidUpdate(sensor: sensor)
    }
}
// swiftlint:enable file_length
