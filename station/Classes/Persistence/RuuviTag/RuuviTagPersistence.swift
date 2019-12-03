import BTKit
import Future
import RealmSwift
import Foundation

protocol RuuviTagPersistence {
    func persist(ruuviTag: RuuviTag, name: String, humidityOffset: Double, humidityOffsetDate: Date?) -> Future<RuuviTag,RUError>
    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func update(humidityOffset: Double, date: Date, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func clearHumidityCalibration(of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    
    @discardableResult
    func update(isConnectable: Bool, of ruuviTag: RuuviTagRealm, realm: Realm) -> Future<Bool,RUError>
    
    @discardableResult
    func persist(ruuviTag: RuuviTagRealm, data: RuuviTag) -> Future<RuuviTag,RUError>
    
    @discardableResult
    func persist(ruuviTagData: RuuviTagDataRealm, realm: Realm) -> Future<Bool,RUError>
    
    @discardableResult
    func update(mac: String?, of ruuviTag: RuuviTagRealm, realm: Realm) -> Future<Bool,RUError>
    
    @discardableResult
    func update(version: Int, of ruuviTag: RuuviTagRealm, realm: Realm) -> Future<Bool,RUError>
    
    @discardableResult
    func persist(logs: [RuuviTagEnvLogFull], for uuid: String) -> Future<Bool,RUError>
    
    @discardableResult
    func clearHistory(uuid: String) -> Future<Bool,RUError>
}
