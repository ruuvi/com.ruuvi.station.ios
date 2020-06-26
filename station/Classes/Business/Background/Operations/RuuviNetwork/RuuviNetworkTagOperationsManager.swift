import Foundation
import RealmSwift
import Future

class RuuviNetworkTagOperationsManager {
    var ruuviNetwork: RuuviNetwork!
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
                    let ruuviNetwork = self?.ruuviNetwork,
                    let ruuviTagTank = self?.ruuviTagTank else {
                    return
                }
                if self?.settings.kaltiotNetworkEnabled == true {
                    operations.append(RuuviTagLoadDataOperation(ruuviTagId: $0.id,
                                                                mac: mac,
                                                                isConnectable: $0.isConnectable,
                                                                network: ruuviNetwork,
                                                                ruuviTagTank: ruuviTagTank))
                }
                if self?.settings.whereOSNetworkEnabled == true {
                    operations.append(RuuviTagLoadDataOperation(ruuviTagId: $0.id,
                                                                mac: mac,
                                                                isConnectable: $0.isConnectable,
                                                                network: ruuviNetwork,
                                                                ruuviTagTank: ruuviTagTank))
                }
            })
            promise.succeed(value: operations)
        }
        return promise.future
    }
}
