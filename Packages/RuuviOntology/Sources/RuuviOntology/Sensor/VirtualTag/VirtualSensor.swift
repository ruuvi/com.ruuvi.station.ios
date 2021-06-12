import Foundation

public protocol VirtualSensor: Sensor {}

public struct VirtualSensorStruct: VirtualSensor {
    public var id: String

    public init(id: String) {
        self.id = id
    }
}
