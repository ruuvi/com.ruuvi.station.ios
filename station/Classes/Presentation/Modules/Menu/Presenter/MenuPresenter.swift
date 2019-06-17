import Foundation

class MenuPresenter: MenuModuleInput {
    weak var view: MenuViewInput!
    var router: MenuRouterInput!
}

extension MenuPresenter: MenuViewOutput {
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
    
    func viewDidSelectAddRuuviTag() {
        router.openDiscover()
    }
    
    func viewDidSelectAbout() {
        
    }
    
    func viewDidSelectGetMoreSensors() {
        
    }
    
    func viewDidSelectSettings() {
        
    }
}
