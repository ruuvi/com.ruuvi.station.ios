import RuuviOntology

extension RuuviDeviceType {
    var displayName: String {
        switch self {
        case .ruuviTag:
            return "RuuviTag"
        case .ruuviAir:
            return "Ruuvi Air"
        }
    }

    var fwVersionPrefix: String {
        switch self {
        case .ruuviTag:
            return "Ruuvi FW"
        case .ruuviAir:
            return "RuuviAir"
        }
    }
}
