import RuuviLocalization
import Foundation
import RuuviOntology

extension RuuviTheme: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .light:
            return { _ in RuuviLocalization.lightTheme }
        case .dark:
            return { _ in RuuviLocalization.darkTheme }
        case .system:
            return { _ in RuuviLocalization.followSystemTheme }
        }
    }
}
