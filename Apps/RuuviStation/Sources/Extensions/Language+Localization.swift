import Foundation
import Humidity
import RuuviLocalization
import RuuviOntology

extension Language {
    var name: String {
        switch self {
        case .english:
            RuuviLocalization.Language.english
        case .finnish:
            RuuviLocalization.Language.finnish
        case .french:
            RuuviLocalization.Language.french
        case .swedish:
            RuuviLocalization.Language.swedish
        case .german:
            RuuviLocalization.Language.german
        case .polish:
            RuuviLocalization.Language.polish
        }
    }
}
