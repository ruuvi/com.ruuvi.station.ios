import Foundation
import Future
import BTKit

protocol RuuviTagService {
    func persist(ruuviTag: RuuviTag, name: String) -> Future<RuuviTag, RUError>
    func persist(mac: String) -> Future<Bool, RUError>
    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool, RUError>
    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool, RUError>
    func clearHistory(uuid: String) -> Future<Bool, RUError>
}
