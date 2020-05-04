import Foundation
import RealmSwift

protocol RuuviTagRealmProtocol: Object {
    var uuid: String { get set }
    var name: String { get set }
    var mac: String? { get set }
    var version: Int { get set }
    var isConnectable: Bool { get set }
    var data: LinkingObjects<RuuviTagDataRealm> { get }
    init(ruuviTag: RuuviTagProtocol, name: String)
}
