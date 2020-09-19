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
}
