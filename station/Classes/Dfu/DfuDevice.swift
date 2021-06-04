struct DfuDevice {
    let uuid: String
    let rssi: Int
    let isConnectable: Bool
    let name: String?
}

extension DfuDevice: Hashable {
    public func hash(into hasher: inout Hasher) {
        let key = uuid
        hasher.combine(key)
    }
}
