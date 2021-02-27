import Foundation
import RealmSwift
import Future

class RuuviNetworkTagOperationsManager {
    var ruuviNetworkFactory: RuuviNetworkFactory!
    var ruuviTagTrunk: RuuviTagTrunk!
    var ruuviTagTank: RuuviTagTank!
    var keychainService: KeychainService!
    var networkPersistance: NetworkPersistence!
    var settings: Settings!

    func pullNetworkTagOperations() -> Future<[Operation], RUError> {
        let promise: Promise<[Operation], RUError> = .init()
        var operations: [Operation] = [Operation]()
        guard keychainService.userIsAuthorized else {
            promise.fail(error: .ruuviNetwork(.doesNotHaveSensors))
            return promise.future
        }
        let networkPruningOffset = -TimeInterval(settings.networkPruningIntervalHours * 60 * 60)
        let networkPruningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let since: Date = networkPersistance.lastSyncDate ?? networkPruningDate
        ruuviTagTrunk.readAll().on { [weak self] (sensors) in
            sensors.forEach({
                guard let mac = $0.macId?.mac,
                    let ruuviNetworkFactory = self?.ruuviNetworkFactory,
                    let ruuviTagTank = self?.ruuviTagTank else {
                    return
                }
                operations.append(RuuviTagLoadDataOperation(ruuviTagId: $0.id,
                                                            mac: mac, since: since,
                                                            network: ruuviNetworkFactory.userApi,
                                                            ruuviTagTank: ruuviTagTank))
            })
            promise.succeed(value: operations)
        }
        return promise.future
    }
}
