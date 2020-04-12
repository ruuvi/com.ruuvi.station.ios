import Foundation
import Future

protocol RuuviNetwork {
    func load(uuid: String, mac: String, isConnectable: Bool) -> Future<[(RuuviTagProtocol, Date)], RUError>
}

class RuuviNetworkFactory {
    var whereOS: RuuviNetworkWhereOS!

    func network(for provider: RuuviNetworkProvider) -> RuuviNetwork {
        switch provider {
        case .whereOS:
            return whereOS
        }
    }
}
