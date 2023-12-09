import Foundation
import RuuviLocalization
import RuuviOntology

extension RuuviTheme: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .light:
            { _ in RuuviLocalization.lightTheme }
        case .dark:
            { _ in RuuviLocalization.darkTheme }
        case .system:
            { _ in RuuviLocalization.followSystemTheme }
        }
    }
}
