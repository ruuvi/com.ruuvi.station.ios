import Foundation

class BackgroundPresenter: BackgroundModuleInput {
    weak var view: BackgroundViewInput!
    var router: BackgroundRouterInput!
    
    func configure() {
        
    }
}

extension BackgroundPresenter: BackgroundViewOutput {
    
}
