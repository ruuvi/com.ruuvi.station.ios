import Foundation

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
        let min = Pressure(300, unit: .hectopascals)?.converted(to: self).value ?? 300
        let max = Pressure(1100, unit: .hectopascals)?.converted(to: self).value ?? 1100
        return .init(uncheckedBounds: (lower: min, upper: max))
    }
}
