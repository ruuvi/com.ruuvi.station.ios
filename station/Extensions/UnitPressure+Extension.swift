import Foundation
import RuuviOntology

extension UnitPressure: SelectionItemProtocol {
    var title: String {
        switch self {
        case .hectopascals:
            return "UnitPressure.hectopascal.title".localized()
        case .inchesOfMercury:
            return "UnitPressure.inchOfMercury.title".localized()
        case .millimetersOfMercury:
            return "UnitPressure.millimetreOfMercury.title".localized()
        default:
            assert(false, "Not allowed")
            return .init()
        }
    }
    var alertRange: Range<Double> {
        let min = Pressure(500, unit: .hectopascals)?.converted(to: self).value ?? 500
        let max = Pressure(1155, unit: .hectopascals)?.converted(to: self).value ?? 1155
        return .init(uncheckedBounds: (lower: min, upper: max))
    }
}
