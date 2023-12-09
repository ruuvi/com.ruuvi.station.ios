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
            { _ in RuuviLocalization.Settings.Measurement.Unit.title }
        case .accuracy:
            { _ in RuuviLocalization.Settings.Measurement.Resolution.title }
        }
    }
}
