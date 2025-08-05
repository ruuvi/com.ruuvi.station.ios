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
        case 90...: // Excellent (green-blue)
            return UIColor(red: 75/255, green: 200/255, blue: 185/255, alpha: 1.0)
        case 80..<90: // Good (green)
            return UIColor(red: 150/255, green: 204/255, blue: 72/255, alpha: 1.0)
        case 60..<80: // Moderate (yellow)
            return UIColor(red: 247/255, green: 225/255, blue: 62/255, alpha: 1.0)
        case 40..<60: // Poor (orange)
            return UIColor(red: 247/255, green: 156/255, blue: 33/255, alpha: 1.0)
        default: // <40, Unhealthy (red)
            return UIColor(red: 237/255, green: 80/255, blue: 33/255, alpha: 1.0)
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
