import UIKit
import RuuviLocalization
import RuuviOntology

extension AirQualityState {
    var color: UIColor {
        // Handle boundary interpolations where edges are not pure states.
        // For example, if the score is 10, it should be a mix of
        // Unhealthy and Poor, not a pure state color.
        switch self.score {
        case 10:
            return RuuviColor.ruuviAQIUnhealthyPoor.color
        case 50:
            return RuuviColor.ruuviAQIPoorModerate.color
        case 80:
            return RuuviColor.ruuviAQIModerateGood.color
        case 90:
            return RuuviColor.ruuviAQIGoodExcellent.color
        default:
            return pureStateColor
        }
    }

    private var pureStateColor: UIColor {
        switch self {
        case .excellent:
            return RuuviColor.ruuviAQIExcellent.color
        case .good:
            return RuuviColor.ruuviAQIGood.color
        case .moderate:
            return RuuviColor.ruuviAQIModerate.color
        case .poor:
            return RuuviColor.ruuviAQIPoor.color
        case .unhealthy:
            return RuuviColor.ruuviAQIUnhealthy.color
        }
    }

    var score: Double {
        switch self {
        case .excellent(let value), .good(let value), .moderate(let value),
             .poor(let value), .unhealthy(let value):
            return value
        }
    }

    var title: String {
        switch self {
        case .excellent:
            return RuuviLocalization.aqiLevelExcellent
        case .good:
            return RuuviLocalization.aqiLevelGood
        case .moderate:
            return RuuviLocalization.aqiLevelModerate
        case .poor:
            return RuuviLocalization.aqiLevelPoor
        case .unhealthy:
            return RuuviLocalization.aqiLevelUnhealthy
        }
    }
}
