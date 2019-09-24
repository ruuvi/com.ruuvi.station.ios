import Foundation
import BTKit
import Future

protocol RuuviTagService {
    func persist(ruuviTag: RuuviTag, name: String) -> Future<RuuviTag,RUError>
    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func loadHistory(uuid: String, from: Date) -> Future<Bool,RUError>
}
