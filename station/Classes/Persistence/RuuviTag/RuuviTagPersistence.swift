import BTKit
import Future
import RealmSwift
import Foundation

protocol RuuviTagPersistence {
    func delete(ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError>
    func update(name: String, of ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError>
    func update(humidityOffset: Double, date: Date, of ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError>
    func clearHumidityCalibration(of ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError>

    @discardableResult
    func update(isConnectable: Bool, of ruuviTag: RuuviTagRealmProtocol, realm: Realm) -> Future<Bool, RUError>

    @discardableResult
    func persist(ruuviTag: RuuviTagRealmProtocol, data: RuuviTag) -> Future<RuuviTag, RUError>

    @discardableResult
    func persist(ruuviTagData: RuuviTagDataRealm, realm: Realm) -> Future<Bool, RUError>

    @discardableResult
    func update(mac: String?, of ruuviTag: RuuviTagRealmProtocol, realm: Realm) -> Future<Bool, RUError>

    @discardableResult
    func update(version: Int, of ruuviTag: RuuviTagRealmProtocol, realm: Realm) -> Future<Bool, RUError>

    @discardableResult
    func persist(logs: [RuuviTagEnvLogFull], for uuid: String) -> Future<Bool, RUError>
}
