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
}
