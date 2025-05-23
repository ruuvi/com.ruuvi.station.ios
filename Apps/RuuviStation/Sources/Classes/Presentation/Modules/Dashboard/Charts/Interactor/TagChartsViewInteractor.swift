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
        andSettings settings: SensorSettings?
    ) {
        ruuviTagSensor = ruuviTag
        sensorSettings = settings
        lastMeasurement = nil
        lastMeasurementRecord = nil
        restartScheduler()
        fetchLast()
        syncFullHistory(for: ruuviTag)

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

    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        guard let luid = ruuviTagSensor.luid
        else {
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
                self?.localSyncState.setGattSyncDate(Date(), for: self?.ruuviTagSensor.macId)
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
        guard let luid = ruuviTagSensor.luid
        else {
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

    func deleteAllRecords(for sensor: RuuviTagSensor) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        ruuviSensorRecords.clear(for: sensor)
            .on(failure: { error in
                promise.fail(error: .ruuviService(error))
            }, completion: { [weak self] in
                self?.localSyncState.setSyncDate(nil, for: self?.ruuviTagSensor.macId)
                self?.localSyncState.setSyncDate(nil)
                self?.localSyncState.setGattSyncDate(nil, for: self?.ruuviTagSensor.macId)
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
        let op = ruuviStorage.readLatest(ruuviTagSensor)
        op.on(success: { [weak self] record in
            guard let sSelf = self else { return }
            guard let record
            else {
                sSelf.presenter.createChartModules(from: [])
                return
            }
            sSelf.lastMeasurement = record.measurement
            sSelf.lastMeasurementRecord = record
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
            // TODO: Double check this logic
            if record.co2 == nil &&
                record.pm2_5 == nil &&
                record.voc == nil &&
                record.nox == nil {
                chartsCases.removeAll { $0 == .aqi }
            }
            if record.co2 == nil {
                chartsCases.removeAll { $0 == .co2 }
            }
            if record.pm2_5 == nil {
                chartsCases.removeAll { $0 == .pm25 }
            }
            if record.pm10 == nil {
                chartsCases.removeAll { $0 == .pm10 }
            }
            if record.voc == nil {
                chartsCases.removeAll { $0 == .voc }
            }
            if record.nox == nil {
                chartsCases.removeAll { $0 == .nox }
            }
            if record.luminance == nil || record.luminance == 0 {
                chartsCases.removeAll { $0 == .luminosity }
            }
            if record.dbaAvg == nil || record.luminance == 0 {
                chartsCases.removeAll { $0 == .sound }
            }
            sSelf.presenter.createChartModules(from: chartsCases)
            sSelf.presenter.updateLatestRecord(record)
        }, failure: { [weak self] error in
            self?.presenter.interactorDidError(.ruuviStorage(error))
        })
    }

    private func fetchLastFromDate() {
        guard let lastMeasurement,
              let lastMeasurementRecord
        else {
            return
        }
        let op = ruuviStorage.readLast(
            ruuviTagSensor.id,
            from: lastMeasurement.date.timeIntervalSince1970
        )
        op.on(success: { [weak self] results in
            guard results.count > 0,
                  let last = results.last
            else {
                self?.presenter.updateLatestRecord(lastMeasurementRecord)
                return
            }
            guard let sSelf = self else { return }
            sSelf.lastMeasurement = last.measurement
            sSelf.lastMeasurementRecord = last
            sSelf.ruuviTagData.append(last.measurement)
            sSelf.insertMeasurements([last.measurement])
            sSelf.presenter.updateLatestRecord(last)
        }, failure: { [weak self] error in
            self?.presenter.updateLatestRecord(lastMeasurementRecord)
            self?.presenter.interactorDidError(.ruuviStorage(error))
        })
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
        let op = ruuviStorage.read(
            ruuviTagSensor.id,
            after: date,
            with: TimeInterval(2)
        )
        op.on(success: { [weak self] results in
            self?.ruuviTagData = results.map(\.measurement)
        }, failure: { [weak self] error in
            self?.presenter.interactorDidError(.ruuviStorage(error))
        }, completion: completion)
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
        let op = ruuviStorage.readDownsampled(
            ruuviTagSensor.id,
            after: date,
            with: highDensityIntervalMinutes,
            pick: maximumPointsCount
        )
        op.on(success: { [weak self] results in
            self?.ruuviTagData = results.map(\.measurement)
        }, failure: { [weak self] error in
            self?.presenter.interactorDidError(.ruuviStorage(error))
        }, completion: competion)
    }

    private func syncFullHistory(for ruuviTag: RuuviTagSensor) {
        if ruuviTag.isCloud && settings.historySyncForEachSensor {
            ruuviStorage.readLatest(ruuviTag).on(success: { [weak self] record in
                if record != nil {
                    self?.cloudSyncService.sync(
                        sensor: ruuviTag
                    ).on(success: {
                        [weak self] _ in
                        self?.restartScheduler()
                    })
                }
            })
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
