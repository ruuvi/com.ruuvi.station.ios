import UIKit
import RuuviOntology

struct DiscoverRuuviTagViewModel {
    var luid: AnyLocalIdentifier?
    var isConnectable: Bool = false
    var rssi: Int?
    var mac: String?
    var name: String?
    var logo: UIImage?
}
