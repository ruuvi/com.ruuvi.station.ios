import Foundation
import Future

protocol NetworkService {
    @discardableResult
    func loadData(for uuid: String, from provider: RuuviNetworkProvider) -> Future<Bool, RUError>
}
