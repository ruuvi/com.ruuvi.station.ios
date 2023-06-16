import Foundation

public enum RuuviAlertSound: String {
    case systemDefault = "default"
    case ruuviSpeak = "ruuvi_speak.caf"

    public var fileName: String {
        switch self {
        case .systemDefault:
            return "default"
        case .ruuviSpeak:
            return "ruuvi_speak"
        }
    }
}
