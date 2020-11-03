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
        operation.on(success: { [weak self] sensor in
            guard let strongSelf = self else {
                return
            }
            let lastRecord = strongSelf.ruuviTagTrunk.readLast(sensor)
            lastRecord.on(success: { (record) in
                let since: Date? = record?.date
                let loadDataOperation = strongSelf.loadDataOperation(for: sensor,
                                                                     mac: mac,
                                                                     since: since,
                                                                     from: provider)
                loadDataOperation.on(success: { (result) in
                    promise.succeed(value: result)
                 }, failure: { (error) in
                    promise.fail(error: error)
                 })
            }, failure: { _ in
                let loadDataOperation = strongSelf.loadDataOperation(for: sensor,
                                                                     mac: mac,
                                                                     from: provider)
                loadDataOperation.on(success: { (result) in
                    promise.succeed(value: result)
                 }, failure: { (error) in
                    promise.fail(error: error)
                 })
            })
        }, failure: { _ in
            promise.fail(error: .unexpected(.failedToFindRuuviTag))
        })
        return promise.future
    }

    private func loadDataOperation(for sensor: AnyRuuviTagSensor,
                                   mac: String,
                                   since: Date? = nil,
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
