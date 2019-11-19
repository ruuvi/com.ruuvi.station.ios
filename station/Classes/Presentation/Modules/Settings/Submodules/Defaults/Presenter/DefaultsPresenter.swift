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
        
        let tagChartsLandscapeSwipeInstructionWasShown = DefaultsViewModel()
        tagChartsLandscapeSwipeInstructionWasShown.title = "Defaults.TagChartsLandscapeSwipeInstructionWasShown.title".localized()
        tagChartsLandscapeSwipeInstructionWasShown.boolean.value = settings.tagChartsLandscapeSwipeInstructionWasShown
        
        bind(tagChartsLandscapeSwipeInstructionWasShown.boolean, fire: false) { observer, tagChartsLandscapeSwipeInstructionWasShown in
            observer.settings.tagChartsLandscapeSwipeInstructionWasShown = tagChartsLandscapeSwipeInstructionWasShown.bound
        }
        
        view.viewModels = [welcomeShown, tagChartsLandscapeSwipeInstructionWasShown]
    }
}

extension DefaultsPresenter: DefaultsViewOutput {
    
}
