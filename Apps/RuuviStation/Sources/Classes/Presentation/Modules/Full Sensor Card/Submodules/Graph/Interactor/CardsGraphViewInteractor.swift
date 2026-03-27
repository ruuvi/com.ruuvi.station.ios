// swiftlint:disable file_length
import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviReactor
import RuuviService
import RuuviStorage

class CardsGraphViewInteractor {
    weak var presenter: CardsGraphViewInteractorOutput!
    var gattService: GATTService!
    var ruuviPool: RuuviPool!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
    var cloudSyncService: RuuviServiceCloudSync!
    var settings: RuuviLocalSettings!
    var flags: RuuviLocalFlags!
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
    private let minimumDownsampleThreshold: Int = 1000
    private var maximumPointsCount: Double {
        Double(min(5000, max(1000, flags.graphDownsampleMaximumPoints)))
    }

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
        ruuviTagData.removeAll()
        restartScheduler()
        fetchLast()

        if syncFromCloud {
            syncFullHistory(for: ruuviTag)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchPoints { [weak self] in
                guard let self else { return }
                self.presenter.interactorDidFinishLoadingHistory()
                self.presenter.interactorDidUpdate(sensor: self.ruuviTagSensor)
            }
        }
    }

    func updateSensorSettings(settings: SensorSettings?) {
        sensorSettings = settings
    }

    func restartObservingData() {
        ruuviTagData.removeAll()
        fetchPoints { [weak self] in
            guard let self else { return }
            self.presenter.interactorDidFinishLoadingHistory()
            self.restartScheduler()
            self.reloadCharts()
        }
    }

    func stopObservingRuuviTagsData() {
        timer?.invalidate()
        timer = nil
    }

    func export() async throws -> URL {
        do {
            return try await exportService.csvLog(
                for: ruuviTagSensor.id,
                version: ruuviTagSensor.version,
                settings: sensorSettings
            )
        } catch {
            throw Self.mapToRUError(error)
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

    func isSyncingRecordsQueued() -> Bool {
        guard let luid = ruuviTagSensor.luid
        else {
            return false
        }
        return gattService.isSyncingLogsQueued(with: luid.value)
    }

    func getLastGattSyncDate() -> Date? {
        guard let ruuviTagSensor = ruuviTagSensor else { return nil }
        return localSyncState.getGattSyncDate(for: ruuviTagSensor.macId)
    }

    func getAutoGattSyncAttemptDate() -> Date? {
        guard let ruuviTagSensor = ruuviTagSensor else { return nil }
        return localSyncState.getAutoGattSyncAttemptDate(for: ruuviTagSensor.macId)
    }

    func setAutoGattSyncAttemptDate(_ date: Date?) {
        guard let ruuviTagSensor = ruuviTagSensor else { return }
        localSyncState.setAutoGattSyncAttemptDate(date, for: ruuviTagSensor.macId)
    }

    func hasLoggedFirstAutoSyncGattHistoryForRuuviAir() -> Bool {
        localSyncState.hasLoggedFirstAutoSyncGattHistoryForRuuviAir(for: ruuviTagSensor.macId)
    }

    func setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(_ logged: Bool) {
        localSyncState.setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(
            logged,
            for: ruuviTagSensor.macId
        )
    }

    func syncRecords(progress: ((BTServiceProgress) -> Void)?) async throws {
        guard let luid = ruuviTagSensor.luid else {
            throw RUError.unexpected(.callbackErrorAndResultAreNil)
        }
        let sensorMacId = ruuviTagSensor.macId
        let connectionTimeout: TimeInterval = settings.connectionTimeout
        let serviceTimeout: TimeInterval = settings.serviceTimeout
        var syncFrom = localSyncState.getGattSyncDate(for: sensorMacId)
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
                mac: sensorMacId?.value,
                firmware: ruuviTagSensor.version,
                from: syncFrom ?? Date.distantPast,
                settings: sensorSettings,
                progress: progress,
                connectionTimeout: connectionTimeout,
                serviceTimeout: serviceTimeout
            )
            if !gattSyncInterruptedByUser {
                localSyncState.setGattSyncDate(Date(), for: sensorMacId)
            }
            gattSyncInterruptedByUser = false
        } catch {
            throw Self.mapToRUError(error)
        }
    }

    func stopSyncRecords() async throws -> Bool {
        guard let luid = ruuviTagSensor.luid else {
            throw RUError.unexpected(.callbackErrorAndResultAreNil)
        }
        do {
            let response = try await gattService.stopGattSync(for: luid.value)
            if response {
                gattSyncInterruptedByUser = true
            }
            return response
        } catch {
            throw Self.mapToRUError(error)
        }
    }

    func deleteAllRecords(for sensor: RuuviTagSensor) async throws {
        do {
            try await ruuviSensorRecords.clear(for: sensor)
            localSyncState.setSyncDate(nil, for: ruuviTagSensor.macId)
            localSyncState.setSyncDate(nil)
            localSyncState.setGattSyncDate(nil, for: ruuviTagSensor.macId)
            localSyncState.setAutoGattSyncAttemptDate(nil, for: ruuviTagSensor.macId)
            restartObservingData()
        } catch {
            throw Self.mapToRUError(error)
        }
    }

    func updateChartShowMinMaxAvgSetting(with show: Bool) async throws {
        do {
            try await ruuviAppSettingsService.set(showMinMaxAvg: show)
        } catch {
            throw Self.mapToRUError(error)
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
        guard let ruuviTagSensor = ruuviTagSensor else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let record = try await self.ruuviStorage.readLatest(ruuviTagSensor)
                guard let record else {
                    self.presenter.createChartModules(from: [])
                    return
                }
                self.lastMeasurement = record.measurement
                self.lastMeasurementRecord = record
                let chartVariants = self.chartVariants(for: record)
                self.presenter.createChartModules(from: chartVariants)
                self.presenter.updateLatestRecord(record)
            } catch let error as RuuviStorageError {
                self.presenter.interactorDidError(.ruuviStorage(error))
            } catch {
                self.presenter.interactorDidError(.persistence(error))
            }
        }
    }

    private func fetchLastFromDate() {
        guard let lastMeasurement,
              let lastMeasurementRecord
        else {
            return
        }
        let sensorId = ruuviTagSensor.id
        Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await self.ruuviStorage.readLast(
                    sensorId,
                    from: lastMeasurement.date.timeIntervalSince1970
                )
                guard results.count > 0,
                      let last = results.last else {
                    self.presenter.updateLatestRecord(lastMeasurementRecord)
                    return
                }
                self.lastMeasurement = last.measurement
                self.lastMeasurementRecord = last
                self.ruuviTagData.append(last.measurement)
                self.insertMeasurements([last.measurement])
                self.presenter.updateLatestRecord(last)
            } catch let error as RuuviStorageError {
                self.presenter.updateLatestRecord(lastMeasurementRecord)
                self.presenter.interactorDidError(.ruuviStorage(error))
            } catch {
                self.presenter.updateLatestRecord(lastMeasurementRecord)
                self.presenter.interactorDidError(.persistence(error))
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
        guard let ruuviTagSensor = ruuviTagSensor else { return }

        let date = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.chartDurationHours,
            to: Date()
        ) ?? Date.distantPast
        Task { [weak self] in
            defer { completion?() }
            guard let self else { return }
            do {
                let results = try await self.ruuviStorage.read(
                    ruuviTagSensor.id,
                    after: date,
                    with: TimeInterval(2)
                )
                self.ruuviTagData = results.map(\.measurement)
            } catch let error as RuuviStorageError {
                self.presenter.interactorDidError(.ruuviStorage(error))
            } catch {
                self.presenter.interactorDidError(.persistence(error))
            }
        }
    }

    private func fetchDownSampled(_ competion: (() -> Void)? = nil) {
        guard let ruuviTagSensor = ruuviTagSensor else { return }

        let date = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.chartDurationHours,
            to: Date()
        ) ?? Date.distantPast
        Task { [weak self] in
            defer { competion?() }
            guard let self else { return }
            do {
                let results = try await self.ruuviStorage.readDownsampled(
                    ruuviTagSensor.id,
                    after: date,
                    with: highDensityIntervalMinutes,
                    pick: maximumPointsCount
                )
                self.ruuviTagData = results.map(\.measurement)
            } catch let error as RuuviStorageError {
                self.presenter.interactorDidError(.ruuviStorage(error))
            } catch {
                self.presenter.interactorDidError(.persistence(error))
            }
        }
    }

    private func syncFullHistory(for ruuviTag: RuuviTagSensor) {
        if ruuviTag.isCloud && settings.historySyncForEachSensor {
            Task { [weak self] in
                guard let self else { return }
                do {
                    if let _ = try await self.ruuviStorage.readLatest(ruuviTag) {
                        _ = try await self.cloudSyncService.sync(sensor: ruuviTag)
                        self.restartScheduler()
                    }
                } catch {
                    return
                }
            }
        }
    }

    private static func mapToRUError(_ error: Error) -> RUError {
        if let error = error as? RUError {
            return error
        }
        if let error = error as? RuuviServiceError {
            return .ruuviService(error)
        }
        if let error = error as? RuuviStorageError {
            return .ruuviStorage(error)
        }
        return .networking(error)
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
