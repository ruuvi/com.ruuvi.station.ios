import Foundation
import Future
import BTKit

protocol RuuviTagService {
    func persist(ruuviTag: RuuviTag, name: String) -> Future<RuuviTag, RUError>
    func delete(ruuviTag: RuuviTagRealmImpl) -> Future<Bool, RUError>
    func update(name: String, of ruuviTag: RuuviTagRealmImpl) -> Future<Bool, RUError>
    func clearHistory(uuid: String) -> Future<Bool, RUError>
}
