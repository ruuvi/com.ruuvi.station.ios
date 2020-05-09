import Foundation
import Future

class NetworkServiceQueue: NetworkService {

    var ruuviNetworkFactory: RuuviNetworkFactory!
    var ruuviTagPersistence: RuuviTagPersistence!
    var realmContext: RealmContext!

    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    @discardableResult
    func loadData(for uuid: String, from provider: RuuviNetworkProvider) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid),
            let mac = ruuviTag.mac {
            let network = ruuviNetworkFactory.network(for: provider)
            let operation = RuuviTagLoadDataOperation(uuid: uuid,
                                                      mac: mac,
                                                      isConnectable: ruuviTag.isConnectable,
                                                      network: network,
                                                      persistence: ruuviTagPersistence)
            operation.completionBlock = { [unowned operation] in
                if let error = operation.error {
                    promise.fail(error: error)
                } else {
                    promise.succeed(value: true)
                }
            }
            queue.addOperation(operation)
        } else {
            promise.fail(error: .unexpected(.failedToFindRuuviTag))
        }
        return promise.future
    }

}
