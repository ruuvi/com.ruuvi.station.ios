import Foundation
import Future
import RuuviOntology

protocol NetworkService {
    @discardableResult
    func loadData(for ruuviTagId: String, mac: String) -> Future<Int, RUError>
    @discardableResult
    func updateTagsInfo() -> Future<Bool, RUError>
}
