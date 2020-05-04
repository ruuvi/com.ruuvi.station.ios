import Foundation
import Future
import BTKit

protocol RuuviTagService {
    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool, RUError>
    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool, RUError>
}
