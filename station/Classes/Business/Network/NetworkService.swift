import Foundation
import Future
import RuuviOntology

protocol NetworkService {
    @discardableResult
    func loadData(for ruuviTagId: String, mac: String, from provider: RuuviNetworkProvider) -> Future<Int, RUError>
    @discardableResult
    func updateTagsInfo(for provider: RuuviNetworkProvider) -> Future<Bool, RUError>
}
