import Foundation
import Future

protocol RuuviNetwork {
    func load(ruuviTagId: String,
              mac: String,
              since: Date,
              until: Date) -> Future<[RuuviTagSensorRecord], RUError>
}

class RuuviNetworkFactory {
    var userApi: RuuviNetworkUserApi!

    func network(for provider: RuuviNetworkProvider) -> RuuviNetwork {
        switch provider {
        case .userApi:
            return userApi
        }
    }
}
