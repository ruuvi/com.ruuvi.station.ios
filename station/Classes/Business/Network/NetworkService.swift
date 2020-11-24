import Foundation
import Future

protocol NetworkService {
    @discardableResult
    func loadData(for ruuviTagId: String, mac: String, from provider: RuuviNetworkProvider) -> Future<Bool, RUError>
    @discardableResult
    func updateTagsInfo(for provider: RuuviNetworkProvider) -> Future<Bool, RUError>
}
