import Foundation
import Humidity
import RuuviOntology
import RuuviLocalization

extension Language {
    var name: String {
        switch self {
        case .english:
            return RuuviLocalization.Language.english
        case .russian:
            return RuuviLocalization.Language.russian
        case .finnish:
            return RuuviLocalization.Language.finnish
        case .french:
            return RuuviLocalization.Language.french
        case .swedish:
            return RuuviLocalization.Language.swedish
        case .german:
            return RuuviLocalization.Language.german
        }
    }
}
