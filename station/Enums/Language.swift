import Foundation

enum Language: String, CaseIterable {
    case english = "en"
    case russian = "ru"
    case finnish = "fi"
    case swedish = "sv"
}

extension Language {
    var name: String {
        switch self {
        case .english:
            return "Language.English".localized()
        case .russian:
            return "Language.Russian".localized()
        case .finnish:
            return "Language.Finnish".localized()
        case .swedish:
            return "Language.Swedish".localized()
        }
    }
}
