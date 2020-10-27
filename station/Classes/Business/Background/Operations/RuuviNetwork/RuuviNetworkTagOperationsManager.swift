import Foundation
import RealmSwift
import Future

class RuuviNetworkTagOperationsManager {
    var ruuviNetworkFactory: RuuviNetworkFactory!
    var ruuviTagTrunk: RuuviTagTrunk!
    var ruuviTagTank: RuuviTagTank!
    var settings: Settings!

    func pullNetworkTagOperations() -> Future<[Operation], RUError> {
        let promise: Promise<[Operation], RUError> = .init()
        var operations: [Operation] = [Operation]()
        guard settings.networkFeatureEnabled else {
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
                // TODO: Add check sensor to userApiType and create operation for synk shared tags
//                if self?.settings.whereOSNetworkEnabled == true {
//                    operations.append(RuuviTagLoadDataOperation(ruuviTagId: $0.id,
//                                                                mac: mac,
//                                                                isConnectable: $0.isConnectable,
//                                                                network: ruuviNetworkFactory.network(for: .whereOS),
//                                                                ruuviTagTank: ruuviTagTank))
//                }
            })
            promise.succeed(value: operations)
        }
        return promise.future
    }
}
