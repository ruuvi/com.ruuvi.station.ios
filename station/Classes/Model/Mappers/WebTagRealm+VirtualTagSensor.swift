import Foundation
import RuuviOntology

extension WebTagRealm: VirtualTagSensor {
    var id: String {
        return uuid
    }
}
