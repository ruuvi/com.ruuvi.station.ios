import Foundation
import Future
import BTKit

class TagChartsInteractor {
    weak var presenter: TagChartsInteractorOutput!
    var gattService: GATTService!
    var ruuviTagTank: RuuviTagTank!
    var ruuviTagTrank: RuuviTagTrunk!
    var settings: Settings!
    var ruuviTagSensor: AnyRuuviTagSensor!
    var exportService: ExportService!
    var lastMeasurement: RuuviMeasurement?
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

    func createChartModules() {
        chartModules = []
        MeasurementType.chartsCases.forEach({
            let viewModel = TagChartViewModel(type: $0)
            let module = TagChartAssembler.createModule()
            module.configure(viewModel, output: self)
            chartModules.append(module)
        })
    }
    func reloadCharts() {
        chartModules.forEach({
            $0.reloadChart()
        })
    }
}
// MARK: - TagChartsInteractorInput
extension TagChartsInteractor: TagChartsInteractorInput {
    func configure(withTag ruuviTag: AnyRuuviTagSensor) {
        ruuviTagSensor = ruuviTag
        lastMeasurement = nil
        createChartModules()
    }
    var chartViews: [TagChartView] {
         return chartModules.map({$0.chartView})
    }
    func restartObservingData() {
        fetchAll { [weak self] in
            self?.startSheduler()
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
            self?.restartObservingData()
            promise.succeed(value: ())
        }, failure: {error in
            promise.fail(error: error)
        })
        return promise.future
    }
    func deleteAllRecords() -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        let op = ruuviTagTank.deleteAllRecords(ruuviTagSensor.id)
        op.on(failure: {(error) in
            promise.fail(error: error)
        }, completion: { [weak self] in
            self?.ruuviTagData = []
            self?.reloadCharts()
            self?.restartObservingData()
            promise.succeed(value: ())
        })
        return promise.future
    }
    // MARK: - Charts
    private func handleUpdateRuuviTagData(_ results: [RuuviTagSensorRecord]) {
            let newValues: [RuuviMeasurement] = results.map({ $0.measurement })
        ruuviTagData.append(contentsOf: newValues)
        chartModules.forEach({
            $0.insertMeasurements(newValues)
        })
    //        let chartIntervalSeconds = settings.chartIntervalSeconds
    //        insertions.forEach({ i in
    //            let newValue = results[i].measurement
    //            let elapsed = Int(newValue.date.timeIntervalSince(lastChartSyncDate))
    //            if elapsed >= chartIntervalSeconds {
    //                lastChartSyncDate = newValue.date
    //                ruuviTagData.append(newValue)
    //                insertMeasurements([newValue], into: viewModel)
    //            }
    //        })
    }
    func notifySettingsChanged() {
        chartModules.forEach({
            $0.notifySettingsChanged()
        })
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
    private func startSheduler() {
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.chartIntervalSeconds),
                                     repeats: true,
                                     block: { [weak self] (_) in
            self?.fetchLast()
        })
    }
    private func fetchLast() {
        guard let lastDate = lastMeasurement?.date.timeIntervalSince1970 else {
            return
        }
        let op = ruuviTagTrank.readLast(ruuviTagSensor.id, from: lastDate)
        op.on(success: { [weak self] (results) in
            guard results.count > 0 else { return }
            let lastResults = results.map({ $0.measurement })
            self?.lastMeasurement = lastResults.last
            self?.ruuviTagData.append(contentsOf: lastResults)
            self?.chartModules.forEach({
                $0.insertMeasurements(lastResults)
            })
        }, failure: {[weak self] (error) in
            self?.presenter.interactorDidError(error)
        })
    }
    private func fetchAll(_ competion: (() -> Void)? = nil) {
        let op = ruuviTagTrank.readAll(ruuviTagSensor.id)
        op.on(success: { [weak self] (results) in
            self?.ruuviTagData = results.map({ $0.measurement })
        }, failure: {[weak self] (error) in
            self?.presenter.interactorDidError(error)
        }, completion: competion)
    }
}
