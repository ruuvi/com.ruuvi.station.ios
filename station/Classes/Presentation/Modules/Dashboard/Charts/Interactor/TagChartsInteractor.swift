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
    var networkService: NetworkService!
    var keychainService: KeychainService!
    var lastMeasurement: RuuviMeasurement?
    private var ruuviTagSensorObservationToken: RUObservationToken!
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
}
// MARK: - TagChartsInteractorInput
extension TagChartsInteractor: TagChartsInteractorInput {
// MARK: - RuuviTags
    func startObservingTags() {
        ruuviTagSensorObservationToken = ruuviTagReactor.observe({ [weak self] change in
            switch change {
            case .delete(let sensor):
                if sensor.id == self?.ruuviTagSensor.id {
                    self?.presenter.interactorDidDeleteTag()
                }
            default:
                return
            }
        })
    }

    func stopObservingTags() {
        ruuviTagSensorObservationToken.invalidate()
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
        var operations = [Future<Void, RUError>]()
        if let luid = ruuviTagSensor.luid {
            operations.append(syncLocalTag(luid: luid.value, progress: progress))
        }
        if settings.kaltiotNetworkEnabled && keychainService.hasKaltiotApiKey {
            operations.append(syncNetworkRecords(with: .kaltiot))
        }
        if settings.whereOSNetworkEnabled {
            operations.append(syncNetworkRecords(with: .whereOS))
        }
        Future.zip(operations).on(success: { [weak self] (_) in
            self?.clearChartsAndRestartObserving()
            promise.succeed(value: ())
        }, failure: { error in
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
            self?.clearChartsAndRestartObserving()
            promise.succeed(value: ())
        })
        return promise.future
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

    private func handleUpdateRuuviTagData(_ results: [RuuviTagSensorRecord]) {
            let newValues: [RuuviMeasurement] = results.map({ $0.measurement })
        ruuviTagData.append(contentsOf: newValues)
        insertMeasurements(newValues)
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

    private func syncLocalTag(luid: String, progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        let connectionTimeout: TimeInterval = settings.connectionTimeout
        let serviceTimeout: TimeInterval = settings.serviceTimeout
        let op = gattService.syncLogs(uuid: luid,
                                      mac: ruuviTagSensor.macId?.value,
                                      progress: progress,
                                      connectionTimeout: connectionTimeout,
                                      serviceTimeout: serviceTimeout)
        op.on(success: { [weak self] _ in
            promise.succeed(value: ())
        }, failure: {error in
            promise.fail(error: error)
        })
        return promise.future
    }

    private func syncNetworkRecords(with provider: RuuviNetworkProvider) -> Future<Void, RUError> {
        let promise = Promise<Void, RUError>()
        if let mac = ruuviTagSensor.macId?.mac {
            let op = networkService.loadData(for: ruuviTagSensor.id, mac: mac, from: provider)
            op.on(success: { [weak self] _ in
                promise.succeed(value: ())
            }, failure: { error in
                promise.fail(error: error)
            })
        } else {
            promise.fail(error: RUError.unexpected(.viewModelUUIDIsNil))
        }
        return promise.future
    }
}
