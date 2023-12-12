import Foundation
import RuuviOntology

enum AppearanceSettingType {
    case theme
}

struct AppearanceSettingsViewModel {
    let title: String
    let items: [SelectionItemProtocol]
    let selection: SelectionItemProtocol
    let type: AppearanceSettingType
}
