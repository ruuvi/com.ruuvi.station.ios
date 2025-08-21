import RuuviDFU

extension RuuviDFUDeviceType {
    var fwVersionPrefix: String {
        switch self {
        case .ruuviTag:
            return "Ruuvi FW"
        case .ruuviAir:
            return "RuuviAir"
        }
    }
}
