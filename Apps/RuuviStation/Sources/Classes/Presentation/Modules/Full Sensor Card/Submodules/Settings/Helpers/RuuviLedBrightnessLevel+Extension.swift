import RuuviOntology
import RuuviLocalization

extension RuuviLedBrightnessLevel {
    static let defaultSelection: RuuviLedBrightnessLevel = .normal

    var title: String {
        switch self {
        case .off:
            return RuuviLocalization.ledLevel0
        case .dim:
            return RuuviLocalization.ledLevel1
        case .normal:
            return RuuviLocalization.ledLevel2
        case .bright:
            return RuuviLocalization.ledLevel3
        }
    }

    var shellArgument: String {
        switch self {
        case .off:
            return "off"
        case .dim:
            return "night"
        case .normal:
            return "day"
        case .bright:
            return "bright_day"
        }
    }
}
