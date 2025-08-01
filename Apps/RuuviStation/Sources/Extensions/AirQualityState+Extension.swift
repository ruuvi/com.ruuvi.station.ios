import UIKit
import RuuviLocalization
import RuuviOntology

extension AirQualityState {
    var color: UIColor {
        let index: Double
        switch self {
        case .excellent(let value),
             .good(let value),
             .moderate(let value),
             .poor(let value),
             .unhealthy(let value):
            index = value
        }

        switch index {
        case 79.5...:
            return UIColor(red: 140/255, green: 198/255, blue: 63/255, alpha: 1.0) // Green
        case 19.5..<79.5:
            return UIColor(red: 247/255, green: 225/255, blue: 62/255, alpha: 1.0) // Yellow
        default: // index < 19.5
            return UIColor(red: 241/255, green: 90/255, blue: 36/255, alpha: 1.0) // Red
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
