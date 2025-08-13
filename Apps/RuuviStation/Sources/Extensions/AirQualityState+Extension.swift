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
        case 66.0...100.0:
            return RuuviColor.green.color
        case 33.0..<66.0:
            return .systemOrange
        default:
            return .systemRed
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
