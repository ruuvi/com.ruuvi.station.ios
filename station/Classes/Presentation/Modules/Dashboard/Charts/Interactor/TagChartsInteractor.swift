import Foundation
import Future
import BTKit

class TagChartsInteractor {
    weak var presenter: TagChartsInteractorOutput!
    var gattService: GATTService!
    var ruuviTagReactor: RuuviTagReactor!
    var ruuviTagTank: RuuviTagTank!
    var settings: Settings!
    var ruuviTagSensor: AnyRuuviTagSensor!
    var exportService: ExportService!
    private var ruuviTagToken: RUObservationToken?
    private var ruuviTagDataToken: RUObservationToken?

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
    private var lastMeasurement: RuuviMeasurement?

    deinit {
        ruuviTagToken?.invalidate()
        ruuviTagDataToken?.invalidate()
    }
}
extension TagChartsInteractor: TagChartsInteractorInput {
    func configure(withTag ruuviTag: AnyRuuviTagSensor) {
        self.ruuviTagSensor = ruuviTag
    }
    func restartObservingData() {
        ruuviTagDataToken?.invalidate()
        ruuviTagDataToken = ruuviTagReactor.observe( ruuviTagSensor.id, { [weak self] results in
            self?.ruuviTagData = results.map({ $0.measurement })
//                self?.handleInitialRuuviTagData(results)
        })
        //        ruuviTagDataToken = ruuviTagDataRealm.observe {
        //            [weak self] (change) in
        //            switch change {
        //            case .initial(let results):
        //                self?.isLoading = true
        //                if results.isEmpty {
        //                    self?.handleEmptyResults()
        //                } else {
        //                    self?.handleInitialRuuviTagData(results)
        //                }
        //                self?.isLoading = false
        //            case .update(let results, _, let insertions, _):
        //                // sync every 1 second
        //                self?.isSyncing = false
        //                if insertions.isEmpty {
        //                    self?.handleEmptyResults()
        //                } else {
        //                    self?.handleUpdateRuuviTagData(results, insertions: insertions)
        //                }
        //            default:
        //                break
        //            }
        //        }
    }
    func stopObservingRuuviTagsData() {
        ruuviTagDataToken?.invalidate()
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
        guard let uuid = ruuviTagSensor.luid else {
            promise.fail(error: .unexpected(.viewModelUUIDIsNil))
            return promise.future
        }
        let connectionTimeout: TimeInterval = settings.connectionTimeout
        let serviceTimeout: TimeInterval = settings.serviceTimeout
        let op = gattService.syncLogs(uuid: uuid,
                                      mac: ruuviTagSensor.mac,
                                      progress: progress,
                                      connectionTimeout: connectionTimeout,
                                      serviceTimeout: serviceTimeout)
        op.on(success: { [weak self] _ in
            self?.ruuviTagData = []
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
            self?.stopObservingRuuviTagsData()
            self?.ruuviTagData = []
            self?.restartObservingData()
            promise.succeed(value: ())
        })
        return promise.future
    }
}
