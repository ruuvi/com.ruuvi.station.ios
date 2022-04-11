import Foundation
import RealmSwift
import BTKit
import RuuviOntology

public final class RuuviTagRealm: Object, RuuviTagRealmProtocol {
    @objc public dynamic var uuid: String = ""
    @objc public dynamic var name: String = ""
    @objc public dynamic var mac: String?
    @objc public dynamic var version: Int = 0
    @objc public dynamic var isConnectable: Bool = false
    @objc public dynamic var isOwner: Bool = true

    public let data = LinkingObjects(fromType: RuuviTagDataRealm.self, property: "ruuviTag")

    public override static func primaryKey() -> String {
        return "uuid"
    }

    public convenience required init(mac: String) {
        self.init()
        self.uuid = UUID().uuidString
        self.mac = mac
        self.name = mac
        self.version = 5
        self.isConnectable = true
        self.isOwner = true
    }

    public convenience required init(ruuviTag: RuuviTagProtocol, name: String) {
        self.init()
        self.uuid = ruuviTag.uuid
        self.name = name
        self.mac = ruuviTag.mac
        self.version = ruuviTag.version
        self.isConnectable = ruuviTag.isConnectable
        self.isOwner = ruuviTag.isOwner
    }

    public convenience required init(ruuviTag: RuuviTagSensor) {
        self.init()
        self.uuid = ruuviTag.id
        self.name = ruuviTag.name
        self.mac = ruuviTag.macId?.value
        self.version = ruuviTag.version
        self.isConnectable = ruuviTag.isConnectable
        self.isOwner = ruuviTag.isOwner
    }
}
