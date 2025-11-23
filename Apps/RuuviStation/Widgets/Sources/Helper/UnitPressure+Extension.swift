import Foundation
import RuuviLocalization
import RuuviOntology

extension UnitPressure {
    var ruuviSymbol: String {
        switch self {
        case .newtonsPerMetersSquared:
            return RuuviLocalization.pressurePaUnit
        default:
            return symbol
        }
    }
}
