import UIKit
import RuuviLocalization
import RuuviOntology

extension AirQualityState {
    var color: UIColor {
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
