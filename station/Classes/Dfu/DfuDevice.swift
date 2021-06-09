struct DfuDevice {
    let uuid: String
    let rssi: Int
    let isConnectable: Bool
    let name: String?
}

extension DfuDevice: Equatable, Hashable {
    public func hash(into hasher: inout Hasher) {
        let key = uuid
        hasher.combine(key)
    }
}

func == (lhs: DfuDevice, rhs: DfuDevice) -> Bool {
    return lhs.uuid == rhs.uuid
}
