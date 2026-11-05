import CoreBluetooth

/// Device identity used by discovery independently of its hardware transport.
public protocol DFUPeripheral: AnyObject {
    var identifier: UUID { get }
}

extension CBPeripheral: DFUPeripheral {}

public struct DFUDevice {
    public let uuid: String
    public let rssi: Int
    public let isConnectable: Bool
    public let name: String?
    public let peripheral: DFUPeripheral

    public init(
        uuid: String,
        rssi: Int,
        isConnectable: Bool,
        name: String?,
        peripheral: DFUPeripheral
    ) {
        self.uuid = uuid
        self.rssi = rssi
        self.isConnectable = isConnectable
        self.name = name
        self.peripheral = peripheral
    }
}

extension DFUDevice: Equatable, Hashable {
    public func hash(into hasher: inout Hasher) {
        let key = uuid
        hasher.combine(key)
    }
}

public func == (lhs: DFUDevice, rhs: DFUDevice) -> Bool {
    lhs.uuid == rhs.uuid
}
