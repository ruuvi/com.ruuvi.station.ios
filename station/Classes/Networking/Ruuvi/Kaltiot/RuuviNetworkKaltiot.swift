import Foundation
import Future
import BTKit

protocol RuuviNetworkKaltiot: RuuviNetwork {
    func validateApiKey(apiKey: String) -> Future<Void, RUError>
    func beacons(page: Int) -> Future<KaltiotBeacons, RUError>
    func history(ids: [String], from: TimeInterval?, to: TimeInterval?) -> Future<[KaltiotBeaconLogs], RUError>
}

extension RuuviNetworkKaltiot {
    func load(uuid: String, mac: String, isConnectable: Bool) -> Future<[(RuuviTagProtocol, Date)], RUError> {
        let promise = Promise<[(RuuviTagProtocol, Date)], RUError>()
        let operation = history(ids: [mac], from: nil, to: nil)
        operation.on(success: { (records) in
            let decoder = Ruuvi.decoder
            guard let log = records.first else {
                return
            }
            let result: [(RuuviTagProtocol, Date)] = log.history.compactMap { (logItem) -> (RuuviTagProtocol, Date)? in
                if let device = decoder.decodeNetwork(uuid: uuid,
                                                      rssi: 0,
                                                      isConnectable: isConnectable,
                                                      payload: logItem.value),
                    let tag = device.ruuvi?.tag {
                    return (tag, logItem.date)
                } else {
                    return nil
                }
            }
            promise.succeed(value: result)
        }, failure: { (error) in
            promise.fail(error: error)
        }, completion: nil)
        return promise.future
    }
}
