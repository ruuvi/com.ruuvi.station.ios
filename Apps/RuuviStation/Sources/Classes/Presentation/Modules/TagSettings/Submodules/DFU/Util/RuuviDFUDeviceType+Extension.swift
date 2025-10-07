import RuuviOntology
import RuuviLocalization

extension RuuviDeviceType {
    var displayName: String {
        switch self {
        case .ruuviTag:
            return RuuviLocalization.ruuviTag
        case .ruuviAir:
            return RuuviLocalization.ruuviAir
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
