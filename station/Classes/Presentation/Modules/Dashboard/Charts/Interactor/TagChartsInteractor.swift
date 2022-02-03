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

    var lastMeasurement: RuuviMeasurement?
    private var ruuviTagSensorObservationToken: RuuviReactorToken?
    private var timer: Timer?
    private var chartModules: [TagChartModuleInput] = []
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

    func createChartModules() {
        chartModules = []
        MeasurementType.chartsCases.forEach({
            let viewModel = TagChartViewModel(type: $0)
            let module = TagChartAssembler.createModule()
            module.configure(viewModel, sensorSettings: sensorSettings, output: self, luid: ruuviTagSensor.luid)
            chartModules.append(module)
        })
    }
}
// MARK: - TagChartsInteractorInput
extension TagChartsInteractor: TagChartsInteractorInput {
    func restartObservingTags() {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = ruuviReactor.observe({ [weak self] change in
            switch change {
            case .initial(let sensors):
                guard let sSelf = self else { return }
                let sensors = sensors.reordered(by: sSelf.settings)
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
        createChartModules()
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
        let op = gattService.syncLogs(uuid: luid.value,
                                      mac: ruuviTagSensor.macId?.value,
                                      settings: sensorSettings,
                                      progress: progress,
                                      connectionTimeout: connectionTimeout,
                                      serviceTimeout: serviceTimeout)
        op.on(success: { _ in
            promise.succeed(value: ())
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
            let matrix = chartView.viewPortHandler.touchMatrix
            otherChart.viewPortHandler.refresh(
                newMatrix: matrix,
                chart: otherChart,
                invalidate: true
            )
        }
    }
}
// MARK: - Private
extension TagChartsInteractor {
    private func restartScheduler() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(settings.chartIntervalSeconds),
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
            var lastResults: [RuuviMeasurement] = []
            var lastMeasurementDate: Date = lastDate
            results.forEach({
                if $0.date >= lastMeasurementDate.addingTimeInterval(interval) {
                    lastMeasurementDate = $0.date
                    lastResults.append($0.measurement)
                }
            })
            self?.lastMeasurement = lastResults.last
            self?.ruuviTagData.append(contentsOf: lastResults)
            self?.insertMeasurements(lastResults)
        }, failure: {[weak self] (error) in
            self?.presenter.interactorDidError(.ruuviStorage(error))
        })
    }

    private func fetchAll(_ competion: (() -> Void)? = nil) {
        let date = Calendar.current.date(
            byAdding: .hour,
            value: -settings.dataPruningOffsetHours,
            to: Date()
        ) ?? Date.distantPast
        let op = ruuviStorage.read(
            ruuviTagSensor.id,
            after: date,
            with: TimeInterval(settings.chartIntervalSeconds)
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

    private func syncLocalTag(luid: String, progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        let connectionTimeout: TimeInterval = settings.connectionTimeout
        let serviceTimeout: TimeInterval = settings.serviceTimeout
        let op = gattService.syncLogs(uuid: luid,
                                      mac: ruuviTagSensor.macId?.value,
                                      settings: sensorSettings,
                                      progress: progress,
                                      connectionTimeout: connectionTimeout,
                                      serviceTimeout: serviceTimeout)
        op.on(success: { _ in
            promise.succeed(value: ())
        }, failure: {error in
            promise.fail(error: .ruuviService(error))
        })
        return promise.future
    }
}
