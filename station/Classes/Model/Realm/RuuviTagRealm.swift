import RealmSwift
import BTKit

class RuuviTagRealm: Object {
    @objc dynamic var uuid: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var mac: String?
    @objc dynamic var version: Int = 0
    
    let data = LinkingObjects(fromType: RuuviTagDataRealm.self, property: "ruuviTag")
    
    override static func primaryKey() -> String {
        return "uuid"
    }
    
    convenience init(ruuviTag: RuuviTag, name: String) {
        self.init()
        self.uuid = ruuviTag.uuid
        self.name = name
        self.mac = ruuviTag.mac
        self.version = ruuviTag.version
    }
}
