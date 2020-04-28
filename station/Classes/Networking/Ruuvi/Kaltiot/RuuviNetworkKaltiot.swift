import Foundation
import Future
import BTKit

protocol RuuviNetworkKaltiot: RuuviNetwork {
    func validateApiKey(apiKey: String) -> Future<Void,RUError>
    func beacons(page:Int) -> Future<KaltiotBeacons, RUError>
}
extension RuuviNetworkKaltiot {
    func load(uuid: String, mac: String, isConnectable: Bool) -> Future<[(RuuviTagProtocol, Date)], RUError> {
        return .init(value: [])
    }
}
