import Foundation

enum Language: String, CaseIterable {
    case english = "en"
    case russian = "ru"
    case finnish = "fi"
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
        }
    }
}
