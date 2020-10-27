import Foundation
import Future

class NetworkServiceQueue: NetworkService {

    var ruuviNetworkFactory: RuuviNetworkFactory!
    var ruuviTagTank: RuuviTagTank!
    var ruuviTagTrunk: RuuviTagTrunk!

    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    @discardableResult
    func loadData(for ruuviTagId: String, mac: String, from provider: RuuviNetworkProvider) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        let operation = ruuviTagTrunk.readOne(ruuviTagId)
        // TODO: Add zip for fetching last record date and add sync for shared tags
        operation.on(success: { [weak self] sensor in
            if let strongSelf = self {
                strongSelf.loadDataOperation(for: sensor,
                                             mac: mac,
                                             since: Date(),
                                             from: provider).on(success: { (result) in
                                                promise.succeed(value: result)
                                             }, failure: { (error) in
                                                promise.fail(error: error)
                                             })
            } else {
                promise.fail(error: .unexpected(.failedToFindLogsForTheTag))
            }
        }, failure: { _ in
            promise.fail(error: .unexpected(.failedToFindRuuviTag))
        })
        return promise.future
    }

    private func loadDataOperation(for sensor: AnyRuuviTagSensor,
                                   mac: String,
                                   since: Date,
                                   from provider: RuuviNetworkProvider) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        let network = ruuviNetworkFactory.network(for: provider)
        let operation = RuuviTagLoadDataOperation(ruuviTagId: sensor.id,
                                                  mac: mac,
                                                  since: since,
                                                  network: network,
                                                  ruuviTagTank: ruuviTagTank)
        operation.completionBlock = { [unowned operation] in
            if let error = operation.error {
                promise.fail(error: error)
            } else {
                promise.succeed(value: true)
            }
        }
        queue.addOperation(operation)
        return promise.future
    }
}
