import Foundation
import RuuviOntology

extension WebTagRealm: VirtualTagSensor {
    public var loc: Location? {
        return location?.location
    }

    public var id: String {
        return uuid
    }
}
