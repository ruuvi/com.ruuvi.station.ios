import RealmSwift
import BTKit
import Foundation

class RuuviTagRealm: Object, RuuviTagRealmProtocol {
    @objc dynamic var uuid: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var mac: String?
    @objc dynamic var version: Int = 0
    @objc dynamic var isConnectable: Bool = false

    // calibration
    @objc dynamic var humidityOffset: Double = 0
    @objc dynamic var humidityOffsetDate: Date?

    let data = LinkingObjects(fromType: RuuviTagDataRealm.self, property: "ruuviTag")

    override static func primaryKey() -> String {
        return "uuid"
    }

    convenience required init(ruuviTag: RuuviTagProtocol, name: String) {
        self.init()
        self.uuid = ruuviTag.uuid
        self.name = name
        self.mac = ruuviTag.mac
        self.version = ruuviTag.version
        self.isConnectable = ruuviTag.isConnectable
    }

    convenience required init(ruuviTag: RuuviTagSensor) {
        self.init()
        self.uuid = ruuviTag.id
        self.name = ruuviTag.name
        self.mac = ruuviTag.mac
        self.version = ruuviTag.version
        self.isConnectable = ruuviTag.isConnectable
    }
}
