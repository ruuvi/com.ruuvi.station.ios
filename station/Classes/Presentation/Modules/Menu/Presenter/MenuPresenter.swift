import Foundation

class MenuPresenter: MenuModuleInput {
    weak var view: MenuViewInput!
    var router: MenuRouterInput!
    
    private weak var output: MenuModuleOutput?
    
    func configure(output: MenuModuleOutput) {
        self.output = output
    }
    
    func dismiss() {
        router.dismiss()
    }
}

extension MenuPresenter: MenuViewOutput {
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
    
    func viewDidSelectAddRuuviTag() {
        output?.menu(module: self, didSelectAddRuuviTag: nil)
    }
    
    func viewDidSelectAbout() {
        
    }
    
    func viewDidSelectGetMoreSensors() {
        
    }
    
    func viewDidSelectSettings() {
        output?.menu(module: self, didSelectSettings: nil)
    }
}
