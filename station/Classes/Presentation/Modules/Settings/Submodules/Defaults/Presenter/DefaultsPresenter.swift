import Foundation

class DefaultsPresenter: NSObject, DefaultsModuleInput {
    weak var view: DefaultsViewInput!
    var router: DefaultsRouterInput!
    var settings: Settings!
    
    func configure() {
        let welcomeShown = DefaultsViewModel()
        welcomeShown.title = "Defaults.WelcomeShown.title".localized()
        welcomeShown.boolean.value = settings.welcomeShown
        
        bind(welcomeShown.boolean, fire: false) { observer, welcomeShown in
            observer.settings.welcomeShown = welcomeShown.bound
        }
        
        view.viewModels = [welcomeShown]
    }
}

extension DefaultsPresenter: DefaultsViewOutput {
    
}
