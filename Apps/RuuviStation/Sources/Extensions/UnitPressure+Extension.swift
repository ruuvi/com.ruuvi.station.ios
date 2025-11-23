import Foundation
import RuuviLocalization
import RuuviOntology

extension UnitPressure: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .hectopascals:
            return { _ in RuuviLocalization.UnitPressure.Hectopascal.title }
        case .newtonsPerMetersSquared:
            return { _ in RuuviLocalization.UnitPressure.Pascal.title }
        case .inchesOfMercury:
            return { _ in RuuviLocalization.UnitPressure.InchOfMercury.title }
        case .millimetersOfMercury:
            return { _ in RuuviLocalization.UnitPressure.MillimetreOfMercury.title }
        default:
            assertionFailure("Not allowed")
            return { _ in .init() }
        }
    }

    var alertRange: Range<Double> {
        let min = Pressure(500, unit: .hectopascals)?.converted(to: self).value ?? 500
        let max = Pressure(1155, unit: .hectopascals)?.converted(to: self).value ?? 1155
        return .init(uncheckedBounds: (lower: min, upper: max))
    }

    var ruuviSymbol: String {
        switch self {
        case .newtonsPerMetersSquared:
            return RuuviLocalization.pressurePaUnit
        default:
            return symbol
        }
    }
}
