import Foundation
import RuuviLocalization

public extension Double {
    var stringValue: String {
        self == 0.0 ? formattedStringValue(places: 0) : String(self)
    }

    func formattedStringValue(places: Int) -> String {
        String(format: "%.\(places)f", self)
    }

    func round(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        let rounded = (self * divisor).rounded(.toNearestOrAwayFromZero) / divisor
        return rounded.isInfinite ? 0 : rounded
    }
}

public extension UnitPressure {
    var ruuviSymbol: String {
        switch self {
        case .newtonsPerMetersSquared:
            return RuuviLocalization.pressurePaUnit
        default:
            return symbol
        }
    }
}
