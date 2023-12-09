import Foundation
import RuuviLocalization

enum UnitSettingsType {
    case unit
    case accuracy
}

extension UnitSettingsType: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .unit:
            return { _ in RuuviLocalization.Settings.Measurement.Unit.title }
        case .accuracy:
            return { _ in RuuviLocalization.Settings.Measurement.Resolution.title }
        }
    }
}
