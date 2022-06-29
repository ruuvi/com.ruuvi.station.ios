import Foundation
import Future
import BTKit
import RuuviOntology
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviPool
import RuuviService

class TagChartsInteractor {
    weak var presenter: TagChartsInteractorOutput!
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

    var lastMeasurement: RuuviMeasurement?
    private var ruuviTagSensorObservationToken: RuuviReactorToken?
    private var timer: Timer?
    var chartModules: [TagChartModuleInput] = []
    private var ruuviTagData: [RuuviMeasurement] = [] {
        didSet {
            if let last = ruuviTagData.last {
                lastMeasurement = last
            } else if let last = oldValue.last {
                lastMeasurement = last
            } else if let last = lastMeasurement,
                ruuviTagData.isEmpty {
                ruuviTagData.append(last)
            }
        }
    }
    private lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    private var sensors: [AnyRuuviTagSensor] = []

    deinit {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
    }

    /// This method creates the chart modules for each sensors i.e. Temperature, Humidity, and Pressure
    /// The missing sensors do not return any chart
    func createChartModules() {
        chartModules = []
        var chartsCases = MeasurementType.chartsCases
        if let last = ruuviTagData.last {
            if last.humidity == nil {
                chartsCases.remove(at: 1)
            } else if last.pressure == nil {
                chartsCases.remove(at: 2)
            }
        }
        chartsCases.forEach({
            let viewModel = TagChartViewModel(type: $0)
            let module = TagChartAssembler.createModule()
            module.configure(viewModel, sensorSettings: sensorSettings, output: self, luid: ruuviTagSensor.luid)
            chartModules.append(module)
        })

        presenter.interactorDidUpdate(sensor: ruuviTagSensor)
    }
}
// MARK: - TagChartsInteractorInput
extension TagChartsInteractor: TagChartsInteractorInput {
    func restartObservingTags() {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = ruuviReactor.observe({ [weak self] change in
            switch change {
            case .initial(let sensors):
                self?.sensors = sensors
                if let id = self?.ruuviTagSensor.id,
                   let sensor = sensors.first(where: {$0.id == id}) {
                    self?.ruuviTagSensor = sensor
                    self?.presenter.interactorDidUpdate(sensor: sensor)
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
        fetchAll { [weak self] in
            self?.createChartModules()
        }
    }

    func updateSensorSettings(settings: SensorSettings?) {
        sensorSettings = settings
    }

    var chartViews: [TagChartView] {
         return chartModules.map({$0.chartView})
    }

    func restartObservingData() {
        fetchAll { [weak self] in
            self?.restartScheduler()
            self?.reloadCharts()
        }
    }

    func stopObservingRuuviTagsData() {
        chartModules = []
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
        let historyLength = Calendar.current.date(
            byAdding: .hour,
            value: -settings.dataPruningOffsetHours,
            to: Date()
        )
        if syncFrom == nil {
            syncFrom = historyLength
        } else if let from = syncFrom, let history = historyLength, from < history {
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
            self?.localSyncState.setGattSyncDate(Date(), for: self?.ruuviTagSensor.macId)
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
        op.on(success: { response in
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
                self?.clearChartsAndRestartObserving()
                promise.succeed(value: ())
            })
        return promise.future
    }

    func notifyDownsamleOnDidChange() {
        self.clearChartsAndRestartObserving()
    }
}
// MARK: - TagChartModuleOutput
extension TagChartsInteractor: TagChartModuleOutput {
    var dataSource: [RuuviMeasurement] {
        return ruuviTagData
    }

    func chartViewDidChangeViewPort(_ chartView: TagChartView) {
        chartViews.filter({ $0 != chartView }).forEach { otherChart in
            let sourceMatrix = chartView.viewPortHandler.touchMatrix
            var targetMatrix = otherChart.viewPortHandler.touchMatrix
            targetMatrix.a = sourceMatrix.a
            targetMatrix.tx = sourceMatrix.tx
            otherChart.viewPortHandler.refresh(
                newMatrix: targetMatrix,
                chart: otherChart,
                invalidate: true
            )
        }
    }
}
// MARK: - Private
extension TagChartsInteractor {
    private func restartScheduler() {
        let timerInterval = settings.appIsOnForeground ? 2 : settings.chartIntervalSeconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(timerInterval),
            repeats: true,
            block: { [weak self] (_) in
                self?.fetchLast()
                self?.removeFirst()
        })
    }

    private func removeFirst() {
        guard !self.settings.chartDownsamplingOn else { return }
        let cropDate = Calendar.current.date(
            byAdding: .hour,
            value: -settings.dataPruningOffsetHours,
            to: Date()
        ) ?? Date.distantPast
        let prunedResults = self.ruuviTagData.filter({ $0.date < cropDate})
        self.ruuviTagData.removeFirst(prunedResults.count)
        self.removeMeasurements(prunedResults)
    }

    private func fetchLast() {
        guard let lastDate = lastMeasurement?.date else {
            return
        }
        let interval = TimeInterval(settings.chartIntervalSeconds)
        let op = ruuviStorage.readLast(ruuviTagSensor.id, from: lastDate.timeIntervalSince1970)
        op.on(success: { [weak self] (results) in
            guard results.count > 0 else { return }
            guard let sSelf = self else { return }
            var lastResults: [RuuviMeasurement] = []
            var lastMeasurementDate: Date = lastDate
            results.forEach({
                if sSelf.settings.appIsOnForeground {
                    lastResults.append($0.measurement)
                } else {
                    if $0.date >= lastMeasurementDate.addingTimeInterval(interval) {
                        lastMeasurementDate = $0.date
                        lastResults.append($0.measurement)
                    }
                }
            })
            sSelf.lastMeasurement = lastResults.last
            sSelf.ruuviTagData.append(contentsOf: lastResults)
            sSelf.insertMeasurements(lastResults)
        }, failure: {[weak self] (error) in
            self?.presenter.interactorDidError(.ruuviStorage(error))
        })
    }

    private func fetchAll(_ competion: (() -> Void)? = nil) {
        let date = Calendar.current.date(
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
        }, completion: competion)
    }

    // MARK: - Charts
    private func handleUpdateRuuviTagData(_ results: [RuuviTagSensorRecord]) {
        let newValues: [RuuviMeasurement] = results.map({ $0.measurement })
        ruuviTagData.append(contentsOf: newValues)
        insertMeasurements(newValues)
    }

    private func clearChartsAndRestartObserving() {
        ruuviTagData = []
        reloadCharts()
        restartObservingData()
    }

    private func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        chartModules.forEach({
            $0.insertMeasurements(newValues)
        })
    }

    private func removeMeasurements(_ oldValues: [RuuviMeasurement]) {
        chartModules.forEach({
            $0.removeMeasurements(oldValues)
        })
    }

    private func reloadCharts() {
        chartModules.forEach({
            $0.reloadChart()
        })
    }

    func notifySettingsChanged() {
        chartModules.forEach({
            $0.notifySettingsChanged()
        })
    }

    func notifyDidLocalized() {
        chartModules.forEach({
            $0.localize()
        })
    }
}
