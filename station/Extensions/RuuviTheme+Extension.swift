import Foundation
import RuuviOntology

extension RuuviTheme: SelectionItemProtocol {
    var title: String {
        switch self {
        case .light:
            return "light_theme".localized()
        case .dark:
            return "dark_theme".localized()
        case .system:
            return "follow_system_theme".localized()
        }
    }
}
