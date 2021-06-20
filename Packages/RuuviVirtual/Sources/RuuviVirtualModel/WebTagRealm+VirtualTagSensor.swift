import Foundation
import RuuviOntology

extension WebTagRealm: VirtualTagSensor {
    public var id: String {
        return uuid
    }
}
