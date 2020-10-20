import Foundation
import Future
import BTKit

class TagChartsInteractor {
    weak var presenter: TagChartsInteractorOutput!
    var gattService: GATTService!
    var ruuviTagTank: RuuviTagTank!
    var ruuviTagTrank: RuuviTagTrunk!
    var ruuviTagReactor: RuuviTagReactor!
    var settings: Settings!
    var ruuviTagSensor: AnyRuuviTagSensor!
    var exportService: ExportService!
    var lastMeasurement: RuuviMeasurement?
    private var ruuviTagSensorObservationToken: RUObservationToken?
    private var didMigrationCompleteToken: NSObjectProtocol?
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
    private var sensors: [AnyRuuviTagSensor] = []

    deinit {
        didMigrationCompleteToken?.invalidate()
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = nil
    }

    func createChartModules() {
        chartModules = []
        MeasurementType.chartsCases.forEach({
            let viewModel = TagChartViewModel(type: $0)
            let module = TagChartAssembler.createModule()
            module.configure(viewModel, output: self, luid: ruuviTagSensor.luid)
            chartModules.append(module)
        })
    }
}
// MARK: - TagChartsInteractorInput
extension TagChartsInteractor: TagChartsInteractorInput {
    func restartObservingTags() {
        ruuviTagSensorObservationToken?.invalidate()
        ruuviTagSensorObservationToken = ruuviTagReactor.observe({ [weak self] change in
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

    func configure(withTag ruuviTag: AnyRuuviTagSensor) {
        ruuviTagSensor = ruuviTag
        lastMeasurement = nil
        createChartModules()
    }

    var chartViews: [TagChartView] {
         return chartModules.map({$0.chartView})
    }

    func restartObservingData() {
        presenter.isLoading = true
        fetchAll { [weak self] in
            self?.startSheduler()
            self?.reloadCharts()
            self?.presenter.isLoading = false
        }
    }

    func stopObservingRuuviTagsData() {
        chartModules = []
        timer?.invalidate()
        timer = nil
    }

    func export() -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        let op = exportService.csvLog(for: ruuviTagSensor.id)
        op.on(success: { (url) in
            promise.succeed(value: url)
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }

    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        guard let luid = ruuviTagSensor.luid else {
            promise.fail(error: .unexpected(.viewModelUUIDIsNil))
            return promise.future
        }
        let connectionTimeout: TimeInterval = settings.connectionTimeout
        let serviceTimeout: TimeInterval = settings.serviceTimeout
        let op = gattService.syncLogs(uuid: luid.value,
                                      mac: ruuviTagSensor.macId?.value,
                                      progress: progress,
                                      connectionTimeout: connectionTimeout,
                                      serviceTimeout: serviceTimeout)
        op.on(success: { [weak self] _ in
            self?.clearChartsAndRestartObserving()
            promise.succeed(value: ())
        }, failure: {error in
            promise.fail(error: error)
        })
        return promise.future
    }

    func deleteAllRecords(ruuviTagId: String) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        let op = ruuviTagTank.deleteAllRecords(ruuviTagId)
        op.on(failure: {(error) in
            promise.fail(error: error)
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
}
// MARK: - Private
extension TagChartsInteractor {
    private func startObserveMigrationCompletion() {
        didMigrationCompleteToken = NotificationCenter
            .default
            .addObserver(forName: .DidMigrationComplete, object: nil, queue: .main, using: { [weak self] (_) in
                self?.restartObservingTags()
            })
    }

    private func startSheduler() {
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.chartIntervalSeconds),
                                     repeats: true,
                                     block: { [weak self] (_) in
            self?.fetchLast()
        })
    }

    private func fetchLast() {
        guard let lastDate = lastMeasurement?.date else {
            return
        }
        let interval = TimeInterval(settings.chartIntervalSeconds)
        let op = ruuviTagTrank.readLast(ruuviTagSensor.id, from: lastDate.timeIntervalSince1970)
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
            self?.presenter.interactorDidError(error)
        })
    }

    private func fetchAll(_ competion: (() -> Void)? = nil) {
        let op = ruuviTagTrank.readAll(ruuviTagSensor.id, with: TimeInterval(settings.chartIntervalSeconds))
        op.on(success: { [weak self] (results) in
            self?.ruuviTagData = results.map({ $0.measurement })
        }, failure: {[weak self] (error) in
            self?.presenter.interactorDidError(error)
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
}
