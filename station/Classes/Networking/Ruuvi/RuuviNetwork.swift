import Foundation
import Future

protocol RuuviNetwork {
    func load(ruuviTagId: String, mac: String, isConnectable: Bool) -> Future<[RuuviTagSensorRecord], RUError>
}

class RuuviNetworkFactory {
    var whereOS: RuuviNetworkWhereOS!
    var kaltiot: RuuviNetworkKaltiot!

    func network(for provider: RuuviNetworkProvider) -> RuuviNetwork {
        switch provider {
        case .kaltiot:
            return kaltiot
        case .whereOS:
            return whereOS
        default:
            fatalError()
        }
    }
}
