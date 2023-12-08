import Foundation
import RuuviOntology
import RuuviLocalization

extension UnitPressure: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .hectopascals:
            return { _ in RuuviLocalization.UnitPressure.Hectopascal.title }
        case .inchesOfMercury:
            return { _ in RuuviLocalization.UnitPressure.InchOfMercury.title }
        case .millimetersOfMercury:
            return { _ in RuuviLocalization.UnitPressure.MillimetreOfMercury.title }
        default:
            assert(false, "Not allowed")
            return { _ in .init() }
        }
    }
    var alertRange: Range<Double> {
        let min = Pressure(500, unit: .hectopascals)?.converted(to: self).value ?? 500
        let max = Pressure(1155, unit: .hectopascals)?.converted(to: self).value ?? 1155
        return .init(uncheckedBounds: (lower: min, upper: max))
    }
}
