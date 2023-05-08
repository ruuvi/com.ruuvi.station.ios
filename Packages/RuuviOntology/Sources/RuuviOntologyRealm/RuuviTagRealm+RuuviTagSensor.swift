import Foundation
import RuuviOntology
import RealmSwift

extension RuuviTagRealm: RuuviTagSensor {
    public var luid: LocalIdentifier? {
        return uuid.luid
    }

    public var macId: MACIdentifier? {
        return mac?.mac
    }

    public var any: AnyRuuviTagSensor {
        return AnyRuuviTagSensor(
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
                isCloudSensor: isCloudSensor,
                canShare: canShare,
                sharedTo: sharedTo
            )
        )
    }

    public var isClaimed: Bool {
        return false
    }
    public var owner: String? {
        return nil
    }
    public var isCloudSensor: Bool? {
        return false
    }
    public var firmwareVersion: String? {
        return nil
    }
    public var canShare: Bool {
        return false
    }
    public var sharedTo: [String] {
        return []
    }
}
