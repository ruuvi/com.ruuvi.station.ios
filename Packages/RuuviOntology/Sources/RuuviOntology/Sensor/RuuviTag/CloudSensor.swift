import Foundation

extension CloudSensor {
    public var ruuviTagSensor: RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: 5,
            luid: nil,
            macId: id.mac,
            isConnectable: true,
            name: name.isEmpty ? id : name,
            isClaimed: isOwner,
            isOwner: isOwner,
            owner: owner
        )
    }
}
