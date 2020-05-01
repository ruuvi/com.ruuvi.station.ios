import Foundation
import Future
import BTKit

protocol RuuviNetworkKaltiot: RuuviNetwork {
    func validateApiKey(apiKey: String) -> Future<Void,RUError>
    func beacons(page:Int) -> Future<KaltiotBeacons, RUError>
    func history(ids: [String], from: TimeInterval?, to: TimeInterval?) -> Future<[KaltiotBeaconLogs], RUError>
    func load(uuid: String, mac: String, isConnectable: Bool) -> Future<[(Ruuvi.Data2, Date)], RUError>
}
extension RuuviNetworkKaltiot {
    func load(uuid: String, mac: String, isConnectable: Bool) -> Future<[(RuuviTagProtocol, Date)], RUError> {
        return .init(value: [])
    }
}
