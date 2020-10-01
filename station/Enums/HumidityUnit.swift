import Foundation

enum HumidityUnit {
    case percent
    case gm3
    case dew
}

extension HumidityUnit: SelectionItemProtocol {
    var title: String {
        switch self {
        case .percent:
            return "HumidityUnit.Percent.title".localized()
        case .gm3:
            return "HumidityUnit.gm3.title".localized()
        case .dew:
            return "HumidityUnit.Dew.title".localized()
        }
    }

    var symbol: String {
        switch self {
        case .percent:
            return "%".localized()
        case .gm3:
            return "g/m³".localized()
        default:
            return "°".localized()
        }
    }

    var alertRange: Range<Double> {
        switch self {
        case .gm3:
            return .init(uncheckedBounds: (lower: 0, upper: 40))
        case .percent:
            return .init(uncheckedBounds: (lower: 0, upper: 100))
        case .dew:
            return .init(uncheckedBounds: (lower: 0, upper: 100))
        }
    }
}
