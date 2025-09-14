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
        case .fair:
            return RuuviColor.ruuviAQIFair.color
        case .poor, .veryPoor:
            return RuuviColor.ruuviAQIPoor.color
        }
    }

    var score: Double {
        switch self {
        case .excellent(let value), .good(let value), .fair(let value),
             .poor(let value), .veryPoor(let value):
            return value
        }
    }

    var title: String {
        switch self {
        case .excellent:
            return RuuviLocalization.excellent
        case .good:
            return RuuviLocalization.good
        case .fair:
            return RuuviLocalization.fair
        case .poor:
            return RuuviLocalization.poor
        case .veryPoor:
            return RuuviLocalization.verypoor
        }
    }
}
