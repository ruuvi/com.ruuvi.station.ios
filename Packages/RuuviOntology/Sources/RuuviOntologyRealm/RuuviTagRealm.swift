import BTKit
import Foundation
import RealmSwift

public final class RuuviTagRealm: Object, RuuviTagRealmProtocol {
    @objc public dynamic var uuid: String = ""
    @objc public dynamic var name: String = ""
    @objc public dynamic var mac: String?
    @objc public dynamic var version: Int = 0
    @objc public dynamic var isConnectable: Bool = false
    @objc public dynamic var isOwner: Bool = true

    public let data = LinkingObjects(fromType: RuuviTagDataRealm.self, property: "ruuviTag")

    override public static func primaryKey() -> String {
        "uuid"
    }

    public required convenience init(mac: String) {
        self.init()
        uuid = UUID().uuidString
        self.mac = mac
        name = mac
        version = 5
        isConnectable = true
        isOwner = true
    }

    public required convenience init(ruuviTag: RuuviTagProtocol, name: String) {
        self.init()
        uuid = ruuviTag.uuid
        self.name = name
        mac = ruuviTag.mac
        version = ruuviTag.version
        isConnectable = ruuviTag.isConnectable
        isOwner = ruuviTag.isOwner
    }

    public required convenience init(ruuviTag: RuuviTagSensor) {
        self.init()
        uuid = ruuviTag.id
        name = ruuviTag.name
        mac = ruuviTag.macId?.value
        version = ruuviTag.version
        isConnectable = ruuviTag.isConnectable
        isOwner = ruuviTag.isOwner
    }
}
