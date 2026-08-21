import Foundation

public protocol PhysicalSensor: Sensor {
    var luid: LocalIdentifier? { get }
    var macId: MACIdentifier? { get }
}

public extension PhysicalSensor {
    var identityKey: String {
        if let macId, !macId.value.isEmpty {
            let suffix = macId.value.macSuffix
            if suffix.count == 8 {
                return "mac:\(suffix)"
            }
            return macId.value
        }
        if let luid {
            return "luid:\(luid.value)"
        }
        return id
    }
}

public struct PhysicalSensorStruct: PhysicalSensor {
    public var id: String {
        if let macId,
           !macId.value.isEmpty {
            macId.value
        } else if let luid {
            luid.value
        } else {
            fatalError()
        }
    }

    public var luid: LocalIdentifier?
    public var macId: MACIdentifier?

    public init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?
    ) {
        self.luid = luid
        self.macId = macId
    }
}
