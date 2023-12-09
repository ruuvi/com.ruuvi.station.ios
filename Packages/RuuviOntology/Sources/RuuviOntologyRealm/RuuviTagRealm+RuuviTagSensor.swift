import Foundation
import RealmSwift
import RuuviOntology

extension RuuviTagRealm: RuuviTagSensor {
    public var luid: LocalIdentifier? {
        uuid.luid
    }

    public var macId: MACIdentifier? {
        mac?.mac
    }

    public var any: AnyRuuviTagSensor {
        AnyRuuviTagSensor(
            object: RuuviTagSensorStruct(
                version: version,
                firmwareVersion: firmwareVersion,
                luid: luid,
                macId: macId,
                isConnectable: isConnectable,
                name: name,
                isClaimed: isClaimed,
                isOwner: isOwner,
                owner: owner,
                ownersPlan: ownersPlan,
                isCloudSensor: isCloudSensor,
                canShare: canShare,
                sharedTo: sharedTo
            )
        )
    }

    public var isClaimed: Bool {
        false
    }

    public var owner: String? {
        nil
    }

    public var ownersPlan: String? {
        nil
    }

    public var isCloudSensor: Bool? {
        false
    }

    public var firmwareVersion: String? {
        nil
    }

    public var canShare: Bool {
        false
    }

    public var sharedTo: [String] {
        []
    }
}
