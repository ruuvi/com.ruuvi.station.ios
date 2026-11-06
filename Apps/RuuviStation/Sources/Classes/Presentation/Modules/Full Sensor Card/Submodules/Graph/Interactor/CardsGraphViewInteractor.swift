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
    private var configurationID = UUID()
    private var observationID = UUID()
    private var sensors: [AnyRuuviTagSensor] = []

    private let highDensityIntervalMinutes: Int = 15
    private let minimumDownsampleThreshold: Int = 1000
    private var maximumPointsCount: Double {
        Double(min(5000, max(1000, flags.graphDownsampleMaximumPoints)))
    }

    deinit {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - TagChartsInteractorInput

extension CardsGraphViewInteractor: CardsGraphViewInteractorInput {
    func restartObservingTags() {
        stopObservingTags()
        let observationID = observationID
        ruuviTagSensorObservationToken = ruuviReactor.observe { [weak self] change in
            let receive = { [weak self] in
                guard let self, self.observationID == observationID else { return }
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
                default:
                    break
                }
            }
            if Thread.isMainThread { receive() } else { DispatchQueue.main.async(execute: receive) }
        }
    }

    func stopObservingTags() {
        observationID = UUID()
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
    }

    func configure(
        withTag ruuviTag: AnyRuuviTagSensor,
        andSettings settings: SensorSettings?,
        syncFromCloud: Bool
    ) {
        configurationID = UUID()
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

        fetchPoints { [weak self] in
            guard let self else { return }
            self.presenter.interactorDidFinishLoadingHistory()
            self.presenter.interactorDidUpdate(sensor: self.ruuviTagSensor)
        }
    }

    func updateSensorSettings(settings: SensorSettings?) {
        sensorSettings = settings
    }

    func restartObservingData() {
        configurationID = UUID()
        ruuviTagData.removeAll()
        fetchPoints { [weak self] in
            guard let self else { return }
            self.presenter.interactorDidFinishLoadingHistory()
            self.restartScheduler()
            self.reloadCharts()
        }
    }

    func stopObservingRuuviTagsData() {
        configurationID = UUID()
        timer?.invalidate()
        timer = nil
    }

    @MainActor func export() async throws(RUError) -> URL {
        do throws(RuuviServiceError) {
            return try await exportService.csvLog(
                for: ruuviTagSensor.id, version: ruuviTagSensor.version, settings: sensorSettings)
        } catch { throw .ruuviService(error) }
    }

    func isSyncingAnyRecords() -> Bool {
        gattService.isSyncingLogs()
    }

    func isSyncingRecords(for luid: LocalIdentifier?) -> Bool {
        guard let luid else { return false }
        return gattService.isSyncingLogs(with: luid.value)
    }

    func isSyncingRecordsQueued(for luid: LocalIdentifier?) -> Bool {
        guard let luid else { return false }
        return gattService.isSyncingLogsQueued(with: luid.value)
    }

    func currentSyncProgress(for luid: LocalIdentifier?) -> BTServiceProgress? {
        guard let luid else { return nil }
        return gattService.syncProgress(with: luid.value)
    }

    func getLastGattSyncDate() -> Date? {
        guard let ruuviTagSensor = ruuviTagSensor else { return nil }
        return localSyncState.getGattSyncDate(for: ruuviTagSensor.macId)
    }

    func isAutoGattSyncSuppressed() -> Bool {
        guard let ruuviTagSensor else { return false }
        return localSyncState.isAutoGattSyncSuppressed(for: ruuviTagSensor.macId)
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

    @MainActor func syncRecords(progress: ((BTServiceProgress) -> Void)?) async throws(RUError) {
        guard let luid = ruuviTagSensor.luid else { throw .unexpected(.callbackErrorAndResultAreNil) }
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
            from < history
        {
            syncFrom = history
        }

        do throws(RuuviServiceError) {
            let completed = try await gattService.syncLogs(
                uuid: luid.value, mac: sensorMacId?.value, firmware: ruuviTagSensor.version,
                from: syncFrom ?? Date.distantPast, settings: sensorSettings, progress: progress,
                timeouts: GATTServiceTimeouts(connection: connectionTimeout, service: serviceTimeout)
            )
            if completed { localSyncState.setGattSyncDate(Date(), for: sensorMacId) }
        } catch { throw .ruuviService(error) }
    }

    @MainActor func stopSyncRecords() async throws(RUError) -> Bool {
        guard let luid = ruuviTagSensor.luid else { throw .unexpected(.callbackErrorAndResultAreNil) }
        do throws(RuuviServiceError) { return try await gattService.stopGattSync(for: luid.value) } catch {
            throw .ruuviService(error)
        }
    }

    @MainActor func deleteAllRecords(for sensor: RuuviTagSensor) async throws(RUError) {
        let syncState = localSyncState!
        let recordsService = ruuviSensorRecords!
        let wasSuppressed = syncState.isAutoGattSyncSuppressed(for: sensor.macId)
        let format = RuuviDataFormat.dataFormat(from: sensor.version)
        if format == .e1 || format == .v6 { syncState.setAutoGattSyncSuppressed(true, for: sensor.macId) }
        do {
            if let luid = sensor.luid { _ = try await gattService.stopGattSync(for: luid.value) }
            _ = try await recordsService.clear(for: sensor)
            if ruuviTagSensor?.id == sensor.id { restartObservingData() }
        } catch {
            if !wasSuppressed { syncState.setAutoGattSyncSuppressed(false, for: sensor.macId) }
            throw .ruuviService(error)
        }
    }

    func updateChartShowMinMaxAvgSetting(with show: Bool) {
        Task { @MainActor [self] in _ = try? await ruuviAppSettingsService.set(showMinMaxAvg: show) }
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
        let cutoff = RuuviHistoryWindow.start(
            limitHours: settings.dataPruningOffsetHours,
            requestedHours: settings.chartShowAll ? nil : settings.chartDurationHours
        )
        let previousCount = ruuviTagData.count
        ruuviTagData.removeAll { $0.date < cutoff }
        if ruuviTagData.count != previousCount, let sensor = ruuviTagSensor {
            presenter.interactorDidUpdate(sensor: sensor)
        }
    }

    private func fetchLast() {
        guard ruuviTagSensor != nil
        else {
            return
        }

        let configurationID = configurationID
        Task { @MainActor [weak self, ruuviStorage = ruuviStorage!, ruuviTagSensor = ruuviTagSensor!] in
            do throws(RuuviStorageError) {
                let value = try await ruuviStorage.readLatest(ruuviTagSensor)
                ({ [weak self] record in
                    guard let sSelf = self, sSelf.configurationID == configurationID else { return }
                    guard let record
                    else {
                        sSelf.presenter.createChartModules(from: [])
                        return
                    }
                    sSelf.lastMeasurement = record.measurement
                    sSelf.lastMeasurementRecord = record
                    let chartVariants = sSelf.chartVariants(for: record)
                    sSelf.presenter.createChartModules(from: chartVariants)
                    sSelf.presenter.updateLatestRecord(record)
                })(value)
            } catch {
                ({ [weak self] error in
                    guard self?.configurationID == configurationID else { return }
                    self?.presenter.interactorDidError(.ruuviStorage(error))
                })(error)
            }
        }
    }

    private func fetchLastFromDate() {
        guard let lastMeasurement,
            let lastMeasurementRecord
        else {
            return
        }

        let configurationID = configurationID
        Task {
            @MainActor [
                weak self, ruuviStorage = ruuviStorage!, ruuviTagSensor = ruuviTagSensor!,
                lastMeasurement = lastMeasurement
            ] in
            do throws(RuuviStorageError) {
                let value = try await ruuviStorage.readLast(
                    ruuviTagSensor.id,
                    from: lastMeasurement.date.timeIntervalSince1970
                )
                ({ [weak self] results in
                    guard self?.configurationID == configurationID else { return }
                    guard results.count > 0,
                        let last = results.last
                    else {
                        self?.presenter.updateLatestRecord(lastMeasurementRecord)
                        return
                    }
                    guard let sSelf = self, sSelf.configurationID == configurationID else { return }
                    sSelf.lastMeasurement = last.measurement
                    sSelf.lastMeasurementRecord = last
                    let cutoff = RuuviHistoryWindow.start(
                        limitHours: sSelf.settings.dataPruningOffsetHours,
                        requestedHours: sSelf.settings.chartShowAll ? nil : sSelf.settings.chartDurationHours
                    )
                    if last.date >= cutoff {
                        sSelf.ruuviTagData.append(last.measurement)
                        sSelf.insertMeasurements([last.measurement])
                    }
                    sSelf.presenter.updateLatestRecord(last)
                })(value)
            } catch {
                ({ [weak self] error in
                    guard self?.configurationID == configurationID else { return }
                    self?.presenter.updateLatestRecord(lastMeasurementRecord)
                    self?.presenter.interactorDidError(.ruuviStorage(error))
                })(error)
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

        let date = RuuviHistoryWindow.start(
            limitHours: settings.dataPruningOffsetHours,
            requestedHours: settings.chartShowAll ? nil : settings.chartDurationHours
        )

        let configurationID = configurationID
        Task { @MainActor [weak self, ruuviStorage = ruuviStorage!, ruuviTagSensor = ruuviTagSensor!] in
            defer { if self?.configurationID == configurationID { completion?() } }
            do throws(RuuviStorageError) {
                let value = try await ruuviStorage.read(
                    ruuviTagSensor.id,
                    after: date,
                    with: TimeInterval(2)
                )
                ({ [weak self] results in
                    guard self?.configurationID == configurationID else { return }
                    self?.ruuviTagData = results.map(\.measurement).filter { $0.date >= date }
                })(value)
            } catch {
                ({ [weak self] error in
                    guard self?.configurationID == configurationID else { return }
                    self?.presenter.interactorDidError(.ruuviStorage(error))
                })(error)
            }
        }
    }

    private func fetchDownSampled(_ competion: (() -> Void)? = nil) {
        guard ruuviTagSensor != nil
        else {
            return
        }

        let date = RuuviHistoryWindow.start(
            limitHours: settings.dataPruningOffsetHours,
            requestedHours: settings.chartShowAll ? nil : settings.chartDurationHours
        )

        let configurationID = configurationID
        Task {
            @MainActor [
                weak self, ruuviStorage = ruuviStorage!, ruuviTagSensor = ruuviTagSensor!,
                highDensityIntervalMinutes = highDensityIntervalMinutes, maximumPointsCount = maximumPointsCount
            ] in
            defer { if self?.configurationID == configurationID { competion?() } }
            do throws(RuuviStorageError) {
                let value = try await ruuviStorage.readDownsampled(
                    ruuviTagSensor.id,
                    after: date,
                    with: highDensityIntervalMinutes,
                    pick: maximumPointsCount
                )
                ({ [weak self] results in
                    guard self?.configurationID == configurationID else { return }
                    self?.ruuviTagData = results.map(\.measurement).filter { $0.date >= date }
                })(value)
            } catch {
                ({ [weak self] error in
                    guard self?.configurationID == configurationID else { return }
                    self?.presenter.interactorDidError(.ruuviStorage(error))
                })(error)
            }
        }
    }

    private func syncFullHistory(for ruuviTag: RuuviTagSensor) {
        guard ruuviTag.isCloud && settings.historySyncForEachSensor else { return }
        let configurationID = configurationID
        Task { @MainActor [weak self, ruuviStorage = ruuviStorage!, cloudSyncService = cloudSyncService!] in
            do {
                let record = try await ruuviStorage.readLatest(ruuviTag)
                guard record != nil, self?.configurationID == configurationID else { return }
                _ = try await cloudSyncService.sync(sensor: ruuviTag)
                guard self?.configurationID == configurationID else { return }
                self?.restartScheduler()
            } catch {
                // Existing local history remains available when the optional cloud refresh fails.
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
