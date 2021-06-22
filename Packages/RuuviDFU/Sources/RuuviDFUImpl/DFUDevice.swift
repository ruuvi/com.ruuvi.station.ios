public struct DFUDevice {
    public let uuid: String
    public let rssi: Int
    public let isConnectable: Bool
    public let name: String?
}

extension DFUDevice: Equatable, Hashable {
    public func hash(into hasher: inout Hasher) {
        let key = uuid
        hasher.combine(key)
    }
}

public func == (lhs: DFUDevice, rhs: DFUDevice) -> Bool {
    return lhs.uuid == rhs.uuid
}
