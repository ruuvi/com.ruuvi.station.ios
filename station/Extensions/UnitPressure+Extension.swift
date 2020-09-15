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
        }
    }
}
