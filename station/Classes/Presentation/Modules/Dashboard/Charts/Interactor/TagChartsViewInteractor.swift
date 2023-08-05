import Foundation
import Future
import BTKit
import RuuviOntology
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviPool
import RuuviService

class TagChartsViewInteractor {
    weak var presenter: TagChartsViewInteractorOutput!
    var gattService: GATTService!
    var ruuviPool: RuuviPool!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
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
        ruuviTagSensorObservationToken = ruuviReactor.observe({ [weak self] change in
            switch change {
            case .initial(let sensors):
                self?.sensors = sensors
                if let id = self?.ruuviTagSensor.id,
                   let sensor = sensors.first(where: {$0.id == id}) {
                    self?.ruuviTagSensor = sensor
                }
            case .insert(let sensor):
                self?.sensors.append(sensor)
            case .update(let sensor):
                if self?.ruuviTagSensor.id == sensor.id,
                   let index = self?.sensors.firstIndex(where: {$0.id == sensor.id}) {
                    self?.ruuviTagSensor = sensor
                    self?.sensors[index] = sensor
                    self?.presenter.interactorDidUpdate(sensor: sensor)
                }
            default:
                return
            }
        })
    }

    func stopObservingTags() {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
    }

    func configure(withTag ruuviTag: AnyRuuviTagSensor,
                   andSettings settings: SensorSettings?) {
        ruuviTagSensor = ruuviTag
        sensorSettings = settings
        lastMeasurement = nil
        lastMeasurementRecord = nil
        restartScheduler()
        fetchLast()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchPoints { [weak self] in
                guard let self = self else { return }
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
            self?.restartScheduler()
            self?.reloadCharts()
        }
    }

    func stopObservingRuuviTagsData() {
        timer?.invalidate()
        timer = nil
    }

    func export() -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        guard let sensorSettings = sensorSettings else {
            return promise.future
        }
        let op = exportService.csvLog(for: ruuviTagSensor.id, settings: sensorSettings)
        op.on(success: { (url) in
            promise.succeed(value: url)
        }, failure: { (error) in
            promise.fail(error: .ruuviService(error))
        })
        return promise.future
    }

    func isSyncingRecords() -> Bool {
        guard let luid = ruuviTagSensor.luid else {
            return false
        }
        if gattService.isSyncingLogs(with: luid.value) {
            return true
        } else {
            return false
        }
    }

    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        guard let luid = ruuviTagSensor.luid else {
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

        let op = gattService.syncLogs(uuid: luid.value,
                                      mac: ruuviTagSensor.macId?.value,
                                      from: syncFrom ?? Date.distantPast,
                                      settings: sensorSettings,
                                      progress: progress,
                                      connectionTimeout: connectionTimeout,
                                      serviceTimeout: serviceTimeout)
        op.on(success: { [weak self] _ in
            if let isInterrupted = self?.gattSyncInterruptedByUser, !isInterrupted {
                self?.localSyncState.setGattSyncDate(Date(), for: self?.ruuviTagSensor.macId)
            }
            self?.gattSyncInterruptedByUser = false
            promise.succeed(value: ())
        }, failure: {error in
            promise.fail(error: .ruuviService(error))
        })
        return promise.future
    }

    func stopSyncRecords() -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        guard let luid = ruuviTagSensor.luid else {
            promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
            return promise.future
        }
        let op = gattService.stopGattSync(for: luid.value)
        op.on(success: { [weak self] response in
            self?.gattSyncInterruptedByUser = true
            promise.succeed(value: (response))
        }, failure: {error in
            promise.fail(error: .ruuviService(error))
        })
        return promise.future
    }

    func deleteAllRecords(for sensor: RuuviTagSensor) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        ruuviSensorRecords.clear(for: sensor)
            .on(failure: {(error) in
                promise.fail(error: .ruuviService(error))
            }, completion: { [weak self] in
                self?.localSyncState.setSyncDate(nil, for: self?.ruuviTagSensor.macId)
                self?.localSyncState.setGattSyncDate(nil, for: self?.ruuviTagSensor.macId)
                self?.restartObservingData()
                promise.succeed(value: ())
            })
        return promise.future
    }

    func updateChartHistoryDurationSetting(with day: Int) {
        ruuviAppSettingsService.set(chartDuration: day)
    }

    func updateChartShowMinMaxAvgSetting(with show: Bool) {
        ruuviAppSettingsService.set(showMinMaxAvg: show)
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
            block: { [weak self] (_) in
                self?.fetchLastFromDate()
                self?.removeFirst()
        })
    }

    private func removeFirst() {
        guard !self.settings.chartDownsamplingOn else { return }
        let cropDate = Calendar.autoupdatingCurrent.date(
            byAdding: .hour,
            value: -settings.dataPruningOffsetHours,
            to: Date()
        ) ?? Date.distantPast
        let prunedResults = self.ruuviTagData.filter({ $0.date < cropDate})
        self.ruuviTagData.removeFirst(prunedResults.count)
    }

    private func fetchLast() {
        guard ruuviTagSensor != nil else {
            return
        }
        let op = ruuviStorage.readLatest(ruuviTagSensor)
        op.on(success: { [weak self] (record) in
            guard let sSelf = self else { return }
            guard let record = record else {
                sSelf.presenter.createChartModules(from: [])
                return
            }
            sSelf.lastMeasurement = record.measurement
            sSelf.lastMeasurementRecord = record
            var chartsCases = MeasurementType.chartsCases
            if record.humidity == nil {
                chartsCases.remove(at: 1)
            } else if record.pressure == nil {
                chartsCases.remove(at: 2)
            }
            sSelf.presenter.createChartModules(from: chartsCases)
            sSelf.presenter.updateLatestRecord(record)
        }, failure: {[weak self] (error) in
            self?.presenter.interactorDidError(.ruuviStorage(error))
        })
    }

    private func fetchLastFromDate() {
        guard let lastMeasurement = lastMeasurement,
              let lastMeasurementRecord = lastMeasurementRecord else {
            return
        }
        let op = ruuviStorage.readLast(
            ruuviTagSensor.id,
            from: lastMeasurement.date.timeIntervalSince1970
        )
        op.on(success: { [weak self] (results) in
            guard results.count > 0,
                  let last = results.last else {
                self?.presenter.updateLatestRecord(lastMeasurementRecord)
                return
            }
            guard let sSelf = self else { return }
            sSelf.lastMeasurement = last.measurement
            sSelf.lastMeasurementRecord = last
            sSelf.ruuviTagData.append(last.measurement)
            sSelf.insertMeasurements([last.measurement])
            sSelf.presenter.updateLatestRecord(last)
        }, failure: {[weak self] (error) in
            self?.presenter.updateLatestRecord(lastMeasurementRecord)
            self?.presenter.interactorDidError(.ruuviStorage(error))
        })
    }

    private func fetchPoints(_ completion: (() -> Void)? = nil) {
        if settings.chartDownsamplingOn {
            fetchAll { [weak self] in
                guard let self = self else {
                    return
                }
                if self.ruuviTagData.count < self.minimumDownsampleThreshold {
                    completion?()
                } else {
                    self.fetchDownSampled(completion)
                }
            }
        } else {
            fetchAll(completion)
        }
    }

    private func fetchAll(_ completion: (() -> Void)? = nil) {
        guard ruuviTagSensor != nil else {
            return
        }

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
        op.on(success: { [weak self] (results) in
            self?.ruuviTagData = results.map({ $0.measurement })
        }, failure: {[weak self] (error) in
            self?.presenter.interactorDidError(.ruuviStorage(error))
        }, completion: completion)
    }

    private func fetchDownSampled(_ competion: (() -> Void)? = nil) {
        guard ruuviTagSensor != nil else {
            return
        }

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
        op.on(success: { [weak self] (results) in
            self?.ruuviTagData = results.map({ $0.measurement })
        }, failure: {[weak self] (error) in
            self?.presenter.interactorDidError(.ruuviStorage(error))
        }, completion: competion)
    }

    // MARK: - Charts
    private func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        presenter.insertMeasurements(newValues)
    }

    private func reloadCharts() {
        presenter.interactorDidUpdate(sensor: ruuviTagSensor)
    }
}
