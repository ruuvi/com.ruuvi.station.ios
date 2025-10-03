import UIKit
import RuuviLocalization
import RuuviOntology

extension MeasurementQualityState {
    var color: UIColor {
        switch self {
        case .excellent:
            return RuuviColor.ruuviMeasurementExcellent.color
        case .good:
            return RuuviColor.ruuviMeasurementGood.color
        case .fair:
            return RuuviColor.ruuviMeasurementFair.color
        case .poor, .veryPoor:
            return RuuviColor.ruuviMeasurementPoor.color
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

extension MeasurementQualityState {
    func isSameQualityLevel(as other: MeasurementQualityState) -> Bool {
        switch (self, other) {
        case (.excellent, .excellent),
             (.good, .good),
             (.fair, .fair),
             (.poor, .poor),
             (.veryPoor, .veryPoor):
            return true
        default:
            return false
        }
    }
}
