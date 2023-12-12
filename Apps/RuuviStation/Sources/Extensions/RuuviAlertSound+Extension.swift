import Foundation
import RuuviLocalization
import RuuviOntology

extension RuuviAlertSound: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .systemDefault: { _ in RuuviLocalization.settingsAlertSoundDefault }
        case .ruuviSpeak: { _ in RuuviLocalization.settingsAlertSoundRuuviSpeak }
        }
    }
}
