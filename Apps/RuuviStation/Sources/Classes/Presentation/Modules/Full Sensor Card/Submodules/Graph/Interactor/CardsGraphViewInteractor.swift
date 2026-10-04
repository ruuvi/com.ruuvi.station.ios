// swiftlint:disable file_length
import BTKit
import Foundation
import UIKit
import Future
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

    private var ruuviTagSensorObservationToken: RuuviReactorToken?
    private var timer: Timer?
    private var sensors: [AnyRuuviTagSensor] = []

    private var historyCancellation = RuuviHistoryCancellation()
    private lazy var historyRefresh = RuuviGraphHistoryRefresh { [weak self] in self?.reloadCharts() }
    private var appStateTokens: [NSObjectProtocol] = []
    private var cloudRequestRunning = false
    private var active = false

    private var gattSyncInterruptedByUser: Bool = false

    deinit {
        historyCancellation.cancel()
        appStateTokens.forEach(NotificationCenter.default.removeObserver)
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
        timer?.invalidate()
        timer = nil
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
                if let id = self?.ruuviTagSensor?.id,
                   let sensor = sensors.first(where: { $0.id == id }) {
                    self?.ruuviTagSensor = sensor
                }
            case let .insert(sensor):
                self?.sensors.append(sensor)
            case let .update(sensor):
                if self?.ruuviTagSensor?.id == sensor.id,
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
        historyCancellation.cancel()
        historyRefresh.cancel()
        cloudRequestRunning = false
        historyCancellation = RuuviHistoryCancellation()
        active = true
        observeAppState()
        ruuviTagSensor = ruuviTag
        sensorSettings = settings
        lastMeasurement = nil
        lastMeasurementRecord = nil
        restartScheduler()
        fetchLast()

        syncFullHistory(for: ruuviTag)

        DispatchQueue.main.async { [weak self] in
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
        guard active else { return }
        historyRefresh.cancel()
        fetchPoints { [weak self] in
            guard let self else { return }
            self.presenter.interactorDidFinishLoadingHistory()
            self.restartScheduler()
            self.reloadCharts()
        }
    }

    func stopObservingRuuviTagsData() {
        active = false
        historyCancellation.cancel()
        historyRefresh.cancel()
        presenter.interactorDidSuspendHistory()
        localSyncState.setSyncStatusHistory(.none, for: ruuviTagSensor?.macId)
        timer?.invalidate()
        timer = nil
    }

    func export() -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        guard let sensorSettings
        else {
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
        guard let luid = ruuviTagSensor?.luid
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
        guard let luid = ruuviTagSensor?.luid
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

    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        guard let luid = ruuviTagSensor?.luid
        else {
            promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
            return promise.future
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

        let op = gattService.syncLogs(
            uuid: luid.value,
            mac: sensorMacId?.value,
            firmware: ruuviTagSensor.version,
            from: syncFrom ?? Date.distantPast,
            settings: sensorSettings,
            progress: progress,
            connectionTimeout: connectionTimeout,
            serviceTimeout: serviceTimeout
        )
        op.on(success: { [weak self] _ in
            if let isInterrupted = self?.gattSyncInterruptedByUser, !isInterrupted {
                self?.localSyncState.setGattSyncDate(Date(), for: sensorMacId)
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
        // The graph can be stopped before configure(withTag:) has supplied a sensor.
        guard let luid = ruuviTagSensor?.luid
        else {
            promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
            return promise.future
        }
        let op = gattService.stopGattSync(for: luid.value)
        op.on(success: { [weak self] response in
            if response {
                self?.gattSyncInterruptedByUser = true
            }
            promise.succeed(value: response)
        }, failure: { error in
            promise.fail(error: .ruuviService(error))
        })
        return promise.future
    }

    func deleteAllRecords(for sensor: RuuviTagSensor) -> Future<Void, RUError> {
        historyCancellation.cancel()
        historyRefresh.cancel()
        cloudRequestRunning = false
        let promise = Promise<Void, RUError>()
        ruuviSensorRecords.clear(for: sensor)
            .on(failure: { error in
                promise.fail(error: .ruuviService(error))
            }, completion: { [weak self] in
                self?.localSyncState.setSyncDate(nil, for: self?.ruuviTagSensor.macId)
                self?.localSyncState.setSyncDate(nil)
                self?.localSyncState.setGattSyncDate(nil, for: self?.ruuviTagSensor.macId)
                self?.localSyncState.setAutoGattSyncAttemptDate(nil, for: self?.ruuviTagSensor.macId)
                self?.restartObservingData()
                promise.succeed(value: ())
            })
        return promise.future
    }

    func updateChartShowMinMaxAvgSetting(with show: Bool) {
        ruuviAppSettingsService.set(showMinMaxAvg: show)
    }
}

// MARK: - Private

extension CardsGraphViewInteractor {
    private func observeAppState() {
        guard appStateTokens.isEmpty else { return }
        appStateTokens.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.historyCancellation.cancel()
            self.historyRefresh.cancel()
            self.presenter.interactorDidSuspendHistory()
            self.localSyncState.setSyncStatusHistory(.none, for: self.ruuviTagSensor?.macId)
            self.timer?.invalidate()
        })
        appStateTokens.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
            guard let self, self.active else { return }
            self.changeHistorySelection()
        })
    }

    private func restartScheduler() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, self.active else { return }
            self.fetchLast()
            self.reloadCharts()
            let range = RuuviGraphHistorySession.selection(settings: self.settings).resolve()
            if range.end >= Date().addingTimeInterval(-60) { self.syncFullHistory(for: self.ruuviTagSensor, revalidate: false) }
        }
    }

    private func fetchLast() {
        guard ruuviTagSensor != nil
        else {
            return
        }
        let sensorID = ruuviTagSensor.id
        let op = ruuviStorage.readLatest(ruuviTagSensor)
        op.on(success: { [weak self] record in
            guard let sSelf = self, sSelf.active, sSelf.ruuviTagSensor.id == sensorID else { return }
            guard let record
            else {
                sSelf.presenter.createChartModules(from: sSelf.orderedChartMeasurementVariants())
                return
            }
            sSelf.lastMeasurement = record.measurement
            sSelf.lastMeasurementRecord = record
            let chartVariants = sSelf.orderedChartMeasurementVariants()
            sSelf.presenter.createChartModules(from: chartVariants)
            sSelf.presenter.updateLatestRecord(record)
        }, failure: { [weak self] error in
            self?.presenter.interactorDidError(.ruuviStorage(error))
        })
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

    func historyRevision() -> Future<Int, RuuviStorageError> { ruuviStorage.historyRevision(ruuviTagSensor.id) }

    func scanHistory(range: RuuviHistoryRange, cancellation: RuuviHistoryCancellation,
                     consume: @escaping (RuuviTagSensorRecord) -> Void) -> Future<Int, RuuviStorageError> {
        ruuviStorage.scanHistory(ruuviTagSensor.id, range: range, cancellation: cancellation, consume: consume)
    }

    func changeHistorySelection() {
        historyCancellation.cancel()
        historyRefresh.cancel()
        historyCancellation = RuuviHistoryCancellation()
        cloudRequestRunning = false
        syncFullHistory(for: ruuviTagSensor)
        restartObservingData()
    }

    private func fetchPoints(_ completion: (() -> Void)? = nil) {
        presenter.createChartModules(from: orderedChartMeasurementVariants())
        completion?()
    }

    private func syncFullHistory(for sensor: RuuviTagSensor, revalidate: Bool = true) {
        guard active, !cloudRequestRunning, settings.appIsOnForeground else { return }
        cloudRequestRunning = true
        presenter.interactorDidUpdateCloudHistory(failed: false)
        let cancellation = historyCancellation
        let range = RuuviGraphHistorySession.selection(settings: settings).resolve()
        cloudSyncService.syncHistory(sensor: sensor, range: range, revalidate: revalidate, cancellation: cancellation,
                                     pageSaved: { [weak self] in
            DispatchQueue.main.async { if !cancellation.isCancelled { self?.historyRefresh.schedule() } }
        }).on(failure: { [weak self] error in
            DispatchQueue.main.async { if !cancellation.isCancelled { self?.presenter.interactorDidUpdateCloudHistory(failed: true) } }
        }, completion: { [weak self] in
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled else { return }
                self.cloudRequestRunning = false
                self.historyRefresh.flush()
            }
        })
    }

    // MARK: - Charts

    private func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        presenter.insertMeasurements(newValues)
    }

    private func reloadCharts() {
        guard active else { return }
        presenter.interactorDidUpdate(sensor: ruuviTagSensor)
    }
}
// swiftlint:enable file_length
