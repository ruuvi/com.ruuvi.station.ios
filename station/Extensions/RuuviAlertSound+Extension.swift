import Foundation
import RuuviOntology

extension RuuviAlertSound: SelectionItemProtocol {
    var title: String {
        switch self {
        case .systemDefault:
          return "settings_alert_sound_default".localized()
        case .ruuviSpeak:
          return "settings_alert_sound_ruuvi_speak".localized()
        }
    }
}
