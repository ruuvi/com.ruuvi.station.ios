import Foundation

enum UnitSettingsType {
    case unit
    case accuracy
}

extension UnitSettingsType: SelectionItemProtocol {
    var title: String {
        switch self {
        case .unit:
            return "Settings.Measurement.Unit.title".localized()
        case .accuracy:
            return "Settings.Measurement.Resolution.title".localized()
        }
    }
}
