import Foundation
import RuuviOntology
import RuuviLocalization

extension RuuviAlertSound: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .systemDefault:
            return { _ in RuuviLocalization.settingsAlertSoundDefault }
        case .ruuviSpeak:
            return { _ in RuuviLocalization.settingsAlertSoundRuuviSpeak }
        }
    }
}
