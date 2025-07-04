import UIKit
import RuuviLocalization
import RuuviOntology

extension AirQualityState {
    var color: UIColor {
        switch self {
        case .excellent:
            return RuuviColor.green.color
        case .medium:
            return RuuviColor.orangeColor.color
        case .unhealthy:
            return .red
        }
    }

    var title: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .medium:
            return "Medium"
        case .unhealthy:
            return "Unhealthy"
        }
    }
}
