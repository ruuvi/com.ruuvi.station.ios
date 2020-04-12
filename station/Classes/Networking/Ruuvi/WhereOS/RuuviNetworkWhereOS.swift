import Foundation
import Future
import BTKit

protocol RuuviNetworkWhereOS: RuuviNetwork {
    func load(mac: String) -> Future<[WhereOSData], RUError>
}

extension RuuviNetworkWhereOS {
    func load(uuid: String, mac: String, isConnectable: Bool) -> Future<[(RuuviTagProtocol, Date)], RUError> {
        let promise = Promise<[(RuuviTagProtocol, Date)], RUError>()
        let operation: Future<[WhereOSData], RUError> = load(mac: mac)
        operation.on(success: { records in
            let decoder = Ruuvi.decoder
            let result = records.compactMap { record -> (RuuviTagProtocol, Date)? in
                if let device = decoder.decodeNetwork(uuid: uuid,
                                                      rssi: record.rssi,
                                                      isConnectable: isConnectable,
                                                      payload: record.data),
                    let tag = device.ruuvi?.tag {
                    return (tag, record.time)
                } else {
                    return nil
                }
            }
            promise.succeed(value: result)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }
}

struct WhereOSData: Codable {
    var rssi: Int
    var rssiMax: Int
    var rssiMin: Int
    var data: String
    var coordinates: String
    var time: Date
    var id: String
    var gwmac: String
}
