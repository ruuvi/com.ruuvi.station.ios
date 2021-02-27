import Foundation
import Humidity

enum Language: String, CaseIterable {
    case english = "en"
    case russian = "ru"
    case finnish = "fi"
    case french = "fr"
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
        case .french:
            return "Language.French".localized()
        case .swedish:
            return "Language.Swedish".localized()
        }
    }

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en_US")
        case .russian:
            return Locale(identifier: "ru_RU")
        case .finnish:
            return Locale(identifier: "fi")
        case .french:
            return Locale(identifier: "fr")
        case .swedish:
            return Locale(identifier: "sv")
        }
    }

    var humidityLanguage: HumiditySettings.Language {
        switch self {
        case .russian:
            return .ru
        case .finnish:
            return .fi
        case .french:
            return .en
        case .swedish:
            return .sv
        case .english:
            return .en
        }
    }
}
