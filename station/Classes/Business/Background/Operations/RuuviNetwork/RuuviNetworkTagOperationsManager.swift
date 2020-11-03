import Foundation
import RealmSwift
import Future

class RuuviNetworkTagOperationsManager {
    var ruuviNetworkFactory: RuuviNetworkFactory!
    var ruuviTagTrunk: RuuviTagTrunk!
    var ruuviTagTank: RuuviTagTank!
    var keychainService: KeychainService!

    func pullNetworkTagOperations() -> Future<[Operation], RUError> {
        let promise: Promise<[Operation], RUError> = .init()
        var operations: [Operation] = [Operation]()
        guard keychainService.userApiIsAuthorized else {
            promise.fail(error: .ruuviNetwork(.doesNotHaveSensors))
            return promise.future
        }
        ruuviTagTrunk.readAll().on { [weak self] (sensors) in
            sensors.forEach({
                guard let mac = $0.macId?.mac,
                    let ruuviNetworkFactory = self?.ruuviNetworkFactory,
                    let ruuviTagTank = self?.ruuviTagTank else {
                    return
                }
                operations.append(RuuviTagLoadDataOperation(ruuviTagId: $0.id,
                                                            mac: mac,
                                                            network: ruuviNetworkFactory.userApi,
                                                            ruuviTagTank: ruuviTagTank))
            })
            promise.succeed(value: operations)
        }
        return promise.future
    }
}
