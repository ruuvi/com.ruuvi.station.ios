import Foundation

extension UnitPressure: SelectionItemProtocol {
    var title: String {
        switch self {
        case .bars:
            return "UnitPressure.bars.title".localized()
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
}
