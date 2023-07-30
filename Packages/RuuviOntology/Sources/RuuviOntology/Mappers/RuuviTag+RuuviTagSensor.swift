import Foundation
import BTKit

extension RuuviTag {
    public func with(name: String) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: nil,
            luid: uuid.luid,
            macId: mac?.mac,
            isConnectable: isConnectable,
            name: name,
            isClaimed: false,
            isOwner: true,
            owner: nil,
            ownersPlan: nil,
            isCloudSensor: false,
            canShare: false,
            sharedTo: []
        )
    }
}
