import BTKit
import Future
import RealmSwift

protocol RuuviTagPersistence {
    func persist(ruuviTag: RuuviTag, name: String) -> Future<RuuviTag,RUError>
    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func update(humidityOffset: Double, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    
    @discardableResult
    func persist(ruuviTag: RuuviTagRealm, data: RuuviTag) -> Future<RuuviTag,RUError>
    
    @discardableResult
    func persist(ruuviTagData: RuuviTagDataRealm, realm: Realm) -> Future<Bool,RUError>
}
