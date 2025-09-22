// swiftlint:disable file_length
import BTKit
import Foundation
// Removed Future dependency after async/await migration
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviReactor
import RuuviService
import RuuviStorage

class TagChartsViewInteractor {
    weak var presenter: TagChartsViewInteractorOutput!
    var gattService: GATTService!
    var ruuviPool: RuuviPool!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
    var cloudSyncService: RuuviServiceCloudSync!
    var settings: RuuviLocalSettings!
    var ruuviTagSensor: AnyRuuviTagSensor!
    var sensorSettings: SensorSettings?
    var exportService: RuuviServiceExport!
    var ruuviSensorRecords: RuuviServiceSensorRecords!
    var featureToggleService: FeatureToggleService!
    var localSyncState: RuuviLocalSyncState!
    var ruuviAppSettingsService: RuuviServiceAppSettings!

    var lastMeasurement: RuuviMeasurement?
    var lastMeasurementRecord: RuuviTagSensorRecord?
    var ruuviTagData: [RuuviMeasurement] = []

    private var ruuviTagSensorObservationToken: RuuviReactorToken?
    private var timer: Timer?
    private var sensors: [AnyRuuviTagSensor] = []

    private let highDensityIntervalMinutes: Int = 15
    private let maximumPointsCount: Double = 3000.0
    private let minimumDownsampleThreshold: Int = 1000

    private var gattSyncInterruptedByUser: Bool = false

    deinit {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
        timer = nil
        timer?.invalidate()
    }
}

// MARK: - TagChartsInteractorInput

extension TagChartsViewInteractor: TagChartsViewInteractorInput {
    func restartObservingTags() {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = ruuviReactor.observe { [weak self] change in
            switch change {
            case let .initial(sensors):
                self?.sensors = sensors
                if let id = self?.ruuviTagSensor.id,
                   let sensor = sensors.first(where: { $0.id == id }) {
                    self?.ruuviTagSensor = sensor
                }
            case let .insert(sensor):
                self?.sensors.append(sensor)
            case let .update(sensor):
                if self?.ruuviTagSensor.id == sensor.id,
                   let index = self?.sensors.firstIndex(where: { $0.id == sensor.id }) {
                    self?.ruuviTagSensor = sensor
                    self?.sensors[index] = sensor
                    self?.presenter.interactorDidUpdate(sensor: sensor)
                }
            default:
                return
            }
        }
    }

    func stopObservingTags() {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
    }

    func configure(
        withTag ruuviTag: AnyRuuviTagSensor,
        andSettings settings: SensorSettings?,
        syncFromCloud: Bool
    ) {
        ruuviTagSensor = ruuviTag
        sensorSettings = settings
        lastMeasurement = nil
        lastMeasurementRecord = nil
        restartScheduler()
        fetchLast()

        if syncFromCloud {
            syncFullHistory(for: ruuviTag)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchPoints { [weak self] in
                guard let self else { return }
                presenter.interactorDidUpdate(sensor: ruuviTagSensor)
            }
        }
    }

    func updateSensorSettings(settings: SensorSettings?) {
        sensorSettings = settings
    }

    func restartObservingData() {
        ruuviTagData.removeAll()
        fetchPoints { [weak self] in
            self?.restartScheduler()
            self?.reloadCharts()
        }
    }

    func stopObservingRuuviTagsData() {
        timer?.invalidate()
        timer = nil
    }

    func export() async throws -> URL {
        guard let sensorSettings else { throw RUError.unexpected(.callbackErrorAndResultAreNil) }
        do {
            return try await exportService.csvLog(
                for: ruuviTagSensor.id,
                version: ruuviTagSensor.version,
                settings: sensorSettings
            )
        } catch let error as RuuviServiceError {
            throw RUError.ruuviService(error)
        } catch {
            throw RUError.unexpected(.callbackErrorAndResultAreNil)
        }
    }

    func isSyncingRecords() -> Bool {
        guard let luid = ruuviTagSensor.luid
        else {
            return false
        }
        if gattService.isSyncingLogs(with: luid.value) {
            return true
        } else {
            return false
        }
    }

    func syncRecords(progress: ((BTServiceProgress) -> Void)?) async throws {
        guard let luid = ruuviTagSensor.luid else {
            throw RUError.unexpected(.callbackErrorAndResultAreNil)
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
        } else if let from = syncFrom, let history = historyLength, from < history {
            syncFrom = history
        }
        do {
            let _ = try await gattService.syncLogs(
                uuid: luid.value,
                mac: ruuviTagSensor.macId?.value,
                firmware: ruuviTagSensor.version,
                from: syncFrom ?? Date.distantPast,
                settings: sensorSettings,
                progress: progress,
                connectionTimeout: connectionTimeout,
                serviceTimeout: serviceTimeout
            )
            if !gattSyncInterruptedByUser {
                localSyncState.setGattSyncDate(Date(), for: ruuviTagSensor.macId)
            }
            gattSyncInterruptedByUser = false
        } catch let error as RuuviServiceError {
            throw RUError.ruuviService(error)
        } catch {
            throw RUError.unexpected(.callbackErrorAndResultAreNil) // generic fallback
        }
    }

    func stopSyncRecords() async throws -> Bool {
        guard let luid = ruuviTagSensor.luid else {
            throw RUError.unexpected(.callbackErrorAndResultAreNil)
        }
        do {
            let result = try await gattService.stopGattSync(for: luid.value)
            gattSyncInterruptedByUser = true
            return result
        } catch let error as RuuviServiceError {
            throw RUError.ruuviService(error)
        } catch {
            throw RUError.unexpected(.callbackErrorAndResultAreNil)
        }
    }

    func deleteAllRecords(for sensor: RuuviTagSensor) async throws {
        do {
            _ = try await ruuviSensorRecords.clear(for: sensor)
            localSyncState.setSyncDate(nil, for: ruuviTagSensor.macId)
            localSyncState.setSyncDate(nil)
            localSyncState.setGattSyncDate(nil, for: ruuviTagSensor.macId)
            restartObservingData()
        } catch let error as RuuviServiceError {
            throw RUError.ruuviService(error)
        } catch {
            throw RUError.unexpected(.callbackErrorAndResultAreNil)
        }
    }

    func updateChartShowMinMaxAvgSetting(with show: Bool) {
//        ruuviAppSettingsService.set(showMinMaxAvg: show)
    }
}

// MARK: - Private

extension TagChartsViewInteractor {
    private func restartScheduler() {
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

    private func removeFirst() {
        guard settings.chartShowAllMeasurements else { return }
        let cropDate = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.dataPruningOffsetHours,
            to: Date()
        ) ?? Date.distantPast
        let prunedResults = ruuviTagData.filter { $0.date < cropDate }
        ruuviTagData.removeFirst(prunedResults.count)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func fetchLast() {
        guard ruuviTagSensor != nil
        else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let record = try await ruuviStorage.readLatest(ruuviTagSensor)
                guard let record else {
                    presenter.createChartModules(from: [])
                    return
                }
                lastMeasurement = record.measurement
                lastMeasurementRecord = record
                var chartsCases = MeasurementType.chartsCases
                if record.temperature == nil { chartsCases.removeAll { $0 == .temperature } }
                if record.humidity == nil { chartsCases.removeAll { $0 == .humidity(settings.humidityUnit) } }
                if record.pressure == nil { chartsCases.removeAll { $0 == .pressure } }
                if record.co2 == nil && record.pm25 == nil { chartsCases.removeAll { $0 == .aqi } }
                if record.co2 == nil { chartsCases.removeAll { $0 == .co2 } }
                if record.pm25 == nil { chartsCases.removeAll { $0 == .pm25 } }
                if record.voc == nil { chartsCases.removeAll { $0 == .voc } }
                if record.nox == nil { chartsCases.removeAll { $0 == .nox } }
                if record.luminance == nil { chartsCases.removeAll { $0 == .luminosity } }
                if record.dbaInstant == nil { chartsCases.removeAll { $0 == .soundInstant } }
                presenter.createChartModules(from: chartsCases)
                presenter.updateLatestRecord(record)
            } catch {
                if let error = error as? RuuviStorageError {
                    presenter.interactorDidError(.ruuviStorage(error))
                }
            }
        }
    }

    private func fetchLastFromDate() {
        guard let lastMeasurement,
              let lastMeasurementRecord
        else {
            return
        }
//        Task { [weak self] in
//            guard let self else { return }
//            do {
//                let results = try await ruuviStorage.readLast(
//                    ruuviTagSensor.id,
//                    from: lastMeasurement.date.timeIntervalSince1970
//                )
//                guard results.count > 0, let last = results.last else {
//                    presenter.updateLatestRecord(lastMeasurementRecord)
//                    return
//                }
//                lastMeasurement = last.measurement
//                lastMeasurementRecord = last
//                ruuviTagData.append(last.measurement)
//                insertMeasurements([last.measurement])
//                presenter.updateLatestRecord(last)
//            } catch {
//                presenter.updateLatestRecord(lastMeasurementRecord)
//                if let error = error as? RuuviStorageError {
//                    presenter.interactorDidError(.ruuviStorage(error))
//                }
//            }
//        }
    }

    private func fetchPoints(_ completion: (() -> Void)? = nil) {
        if settings.chartShowAllMeasurements {
            fetchAll(completion)
        } else {
            fetchAll { [weak self] in
                guard let self
                else {
                    return
                }
                if ruuviTagData.count < minimumDownsampleThreshold {
                    completion?()
                } else {
                    fetchDownSampled(completion)
                }
            }
        }
    }

    private func fetchAll(_ completion: (() -> Void)? = nil) {
        guard ruuviTagSensor != nil
        else {
            return
        }

        let date = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.chartDurationHours,
            to: Date()
        ) ?? Date.distantPast
        Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await ruuviStorage.read(
                    ruuviTagSensor.id,
                    after: date,
                    with: TimeInterval(2)
                )
                ruuviTagData = results.map(\.measurement)
                completion?()
            } catch {
                if let error = error as? RuuviStorageError {
                    presenter.interactorDidError(.ruuviStorage(error))
                }
                completion?()
            }
        }
    }

    private func fetchDownSampled(_ competion: (() -> Void)? = nil) {
        guard ruuviTagSensor != nil
        else {
            return
        }

        let date = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.chartDurationHours,
            to: Date()
        ) ?? Date.distantPast
        Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await ruuviStorage.readDownsampled(
                    ruuviTagSensor.id,
                    after: date,
                    with: highDensityIntervalMinutes,
                    pick: maximumPointsCount
                )
                ruuviTagData = results.map(\.measurement)
                competion?()
            } catch {
                if let error = error as? RuuviStorageError {
                    presenter.interactorDidError(.ruuviStorage(error))
                }
                competion?()
            }
        }
    }

    private func syncFullHistory(for ruuviTag: RuuviTagSensor) {
        if ruuviTag.isCloud && settings.historySyncForEachSensor {
            Task { [weak self] in
                guard let self else { return }
                let record = try? await ruuviStorage.readLatest(ruuviTag)
                if record != nil {
                    _ = try? await cloudSyncService.sync(sensor: ruuviTag)
                    restartScheduler()
                }
            }
        }
    }

    // MARK: - Charts

    private func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        presenter.insertMeasurements(newValues)
    }

    private func reloadCharts() {
        presenter.interactorDidUpdate(sensor: ruuviTagSensor)
    }
}
// swiftlint:enable file_length
