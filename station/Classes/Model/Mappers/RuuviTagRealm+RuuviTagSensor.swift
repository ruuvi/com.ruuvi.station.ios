import Foundation
import RuuviOntology

extension RuuviTagRealm: RuuviTagSensor {
    var luid: LocalIdentifier? {
        return uuid.luid
    }

    var macId: MACIdentifier? {
        return mac?.mac
    }

    var any: AnyRuuviTagSensor {
        return AnyRuuviTagSensor(
            object: RuuviTagSensorStruct(
                version: version,
                luid: luid,
                macId: macId,
                isConnectable: isConnectable,
                name: name,
                isClaimed: isClaimed,
                isOwner: isOwner,
                owner: owner
            )
        )
    }
    
    var isClaimed: Bool {
        return false
    }
    var isOwner: Bool {
        return true
    }
    var owner: String? {
        return nil
    }
}
