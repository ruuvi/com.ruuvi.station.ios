// swiftlint:disable file_length
import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviReactor
import RuuviService
import RuuviStorage

@MainActor
class CardsGraphViewInteractor {
    weak var presenter: CardsGraphViewInteractorOutput!
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

extension CardsGraphViewInteractor: CardsGraphViewInteractorInput {
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

        fetchPoints { [weak self] in
            guard let self else { return }
            presenter.interactorDidUpdate(sensor: ruuviTagSensor)
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
        guard let sensorSettings else {
            throw RUError.unexpected(.callbackErrorAndResultAreNil)
        }
        do {
            return try await exportService.csvLog(
                for: ruuviTagSensor.id,
                version: ruuviTagSensor.version,
                settings: sensorSettings
            )
        } catch let error as RuuviServiceError {
            throw RUError.ruuviService(error)
        } catch {
            throw RUError.networking(error)
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

    func syncRecords(progress: ((BTServiceProgress) -> Void)?) async throws -> Void {
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
        } else if let from = syncFrom,
                  let history = historyLength,
                  from < history {
            syncFrom = history
        }

        do {
            _ = try await gattService.syncLogs(
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
            throw RUError.networking(error)
        }
    }

    func stopSyncRecords() async throws -> Bool {
        guard let luid = ruuviTagSensor.luid else {
            throw RUError.unexpected(.callbackErrorAndResultAreNil)
        }
        do {
            let response = try await gattService.stopGattSync(for: luid.value)
            gattSyncInterruptedByUser = true
            return response
        } catch let error as RuuviServiceError {
            throw RUError.ruuviService(error)
        } catch {
            throw RUError.networking(error)
        }
    }

    func deleteAllRecords(for sensor: RuuviTagSensor) async throws -> Void {
        do {
            try await ruuviSensorRecords.clear(for: sensor)
            localSyncState.setSyncDate(nil, for: ruuviTagSensor.macId)
            localSyncState.setSyncDate(nil)
            localSyncState.setGattSyncDate(nil, for: ruuviTagSensor.macId)
            restartObservingData()
        } catch let error as RuuviServiceError {
            throw RUError.ruuviService(error)
        } catch {
            throw RUError.networking(error)
        }
    }

    func updateChartShowMinMaxAvgSetting(with show: Bool) {
        Task {
            _ = try? await ruuviAppSettingsService.set(showMinMaxAvg: show)
        }
    }
}

// MARK: - Private

extension CardsGraphViewInteractor {
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

    private func fetchLast() {
        guard ruuviTagSensor != nil
        else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let record = try await ruuviStorage.readLatest(ruuviTagSensor)
                guard let record else {
                    presenter.createChartModules(from: [])
                    return
                }
                lastMeasurement = record.measurement
                lastMeasurementRecord = record
                let chartVariants = chartVariants(for: record)
                presenter.createChartModules(from: chartVariants)
                presenter.updateLatestRecord(record)
            } catch let error as RuuviStorageError {
                presenter.interactorDidError(.ruuviStorage(error))
            } catch {
                presenter.interactorDidError(.networking(error))
            }
        }
    }

    private func fetchLastFromDate() {
        guard let lastMeasurement,
              let lastMeasurementRecord
        else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let results = try await ruuviStorage.readLast(
                    ruuviTagSensor.id,
                    from: lastMeasurement.date.timeIntervalSince1970
                )
                guard results.count > 0,
                      let last = results.last
                else {
                    presenter.updateLatestRecord(lastMeasurementRecord)
                    return
                }
                lastMeasurement = last.measurement
                lastMeasurementRecord = last
                ruuviTagData.append(last.measurement)
                insertMeasurements([last.measurement])
                presenter.updateLatestRecord(last)
            } catch let error as RuuviStorageError {
                presenter.updateLatestRecord(lastMeasurementRecord)
                presenter.interactorDidError(.ruuviStorage(error))
            } catch {
                presenter.updateLatestRecord(lastMeasurementRecord)
                presenter.interactorDidError(.networking(error))
            }
        }
    }

    private func chartVariants(
        for record: RuuviTagSensorRecord
    ) -> [MeasurementDisplayVariant] {
        return orderedChartMeasurementVariants()
            .filter {
                record.hasMeasurement(
                    for: $0.type
                )
        }
    }

    private func orderedChartMeasurementVariants() -> [MeasurementDisplayVariant] {
        let profile: MeasurementDisplayProfile
        if let sensor = ruuviTagSensor {
            profile = RuuviTagDataService.measurementDisplayProfile(for: sensor)
        } else {
            profile = RuuviTagDataService.defaultMeasurementDisplayProfile()
        }

        return profile.orderedVisibleVariants(for: .graph)
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
        Task { @MainActor [weak self] in
            guard let self else {
                completion?()
                return
            }
            do {
                let results = try await ruuviStorage.read(
                    ruuviTagSensor.id,
                    after: date,
                    with: TimeInterval(2)
                )
                ruuviTagData = results.map(\.measurement)
            } catch let error as RuuviStorageError {
                presenter.interactorDidError(.ruuviStorage(error))
            } catch {
                presenter.interactorDidError(.networking(error))
            }
            completion?()
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
        Task { @MainActor [weak self] in
            guard let self else {
                competion?()
                return
            }
            do {
                let results = try await ruuviStorage.readDownsampled(
                    ruuviTagSensor.id,
                    after: date,
                    with: highDensityIntervalMinutes,
                    pick: maximumPointsCount
                )
                ruuviTagData = results.map(\.measurement)
            } catch let error as RuuviStorageError {
                presenter.interactorDidError(.ruuviStorage(error))
            } catch {
                presenter.interactorDidError(.networking(error))
            }
            competion?()
        }
    }

    private func syncFullHistory(for ruuviTag: RuuviTagSensor) {
        if ruuviTag.isCloud && settings.historySyncForEachSensor {
            Task { @MainActor [weak self] in
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
