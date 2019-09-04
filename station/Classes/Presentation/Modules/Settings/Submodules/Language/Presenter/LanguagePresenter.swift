import Foundation

class LanguagePresenter: LanguageModuleInput {
    weak var view: LanguageViewInput!
    var router: LanguageRouterInput!
    var settings: Settings!
}

extension LanguagePresenter: LanguageViewOutput {
    func viewDidLoad() {
        view.languages = Language.allCases
    }
    
    func viewDidSelect(language: Language) {
        settings.language = language
        LocalizationService.shared.localization = language.rawValue
        router.dismiss()
    }
}
