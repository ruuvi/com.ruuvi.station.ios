import Foundation
import BTKit

extension RuuviTag {
    public func with(name: String) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            luid: uuid.luid,
            macId: mac?.mac,
            isConnectable: isConnectable,
            name: name,
            isClaimed: false,
            isOwner: true,
            owner: nil
        )
    }
}
