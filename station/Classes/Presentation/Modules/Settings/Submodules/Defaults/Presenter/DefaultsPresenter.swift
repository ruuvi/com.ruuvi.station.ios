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
        
        let connectionTimeout = DefaultsViewModel()
        connectionTimeout.title = "Defaults.ConnectionTimeout.title".localized()
        connectionTimeout.integer.value = Int(settings.connectionTimeout)
        
        bind(connectionTimeout.integer, fire: false) { observer, connectionTimeout in
            observer.settings.connectionTimeout = TimeInterval(connectionTimeout.bound)
        }
        
        
        let serviceTimeout = DefaultsViewModel()
        serviceTimeout.title = "Defaults.ServiceTimeout.title".localized()
        serviceTimeout.integer.value = Int(settings.serviceTimeout)
        
        bind(serviceTimeout.integer, fire: false) { observer, serviceTimeout in
            observer.settings.serviceTimeout = TimeInterval(serviceTimeout.bound)
        }
        
        view.viewModels = [welcomeShown, tagChartsLandscapeSwipeInstructionWasShown, connectionTimeout, serviceTimeout]
    }
}

extension DefaultsPresenter: DefaultsViewOutput {
    
}
