import BTKit
import Foundation

public extension RuuviTag {
    func with(name: String) -> RuuviTagSensor {
        RuuviTagSensorStruct(
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
            sharedTo: [],
            maxHistoryDays: nil
        )
    }
}
