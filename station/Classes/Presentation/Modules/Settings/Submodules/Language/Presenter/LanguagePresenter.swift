import Foundation
import RuuviOntology
import RuuviLocal

class LanguagePresenter: LanguageModuleInput {
    weak var view: LanguageViewInput!
    var router: LanguageRouterInput!
    var settings: RuuviLocalSettings!
}

extension LanguagePresenter: LanguageViewOutput {
    func viewDidLoad() {
        view.languages = Language.allCases
        view.selectedLanguage = settings.language
    }

    func viewDidSelect(language: Language) {
        settings.language = language
        LocalizationService.shared.localization = language.rawValue
        router.dismiss()
    }
}
