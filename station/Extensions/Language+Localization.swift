import Foundation
import Humidity
import RuuviOntology

extension Language {
    var name: String {
        switch self {
        case .english:
            return "Language.English".localized()
        case .russian:
            return "Language.Russian".localized()
        case .finnish:
            return "Language.Finnish".localized()
        case .french:
            return "Language.French".localized()
        case .swedish:
            return "Language.Swedish".localized()
        case .german:
            return "Language.German".localized()
        }
    }
}
