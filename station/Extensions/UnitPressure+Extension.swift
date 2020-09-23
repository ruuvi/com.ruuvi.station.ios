import Foundation

extension UnitPressure: SelectionItemProtocol {
    var title: String {
        switch self {
        case .bars:
            return "UnitPressure.bars.title".localized()
        case .hectopascals:
            return "UnitPressure.hectopascals.title".localized()
        case .inchesOfMercury:
            return "UnitPressure.inchesOfMercury.title".localized()
        case .millimetersOfMercury:
            return "UnitPressure.millimetersOfMercury.title".localized()
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
