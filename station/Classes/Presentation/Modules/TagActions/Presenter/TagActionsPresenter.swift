import Foundation

class TagActionsPresenter: TagActionsModuleInput {
    weak var view: TagActionsViewInput!
    var router: TagActionsRouterInput!
    
    func configure() {
        
    }
}

extension TagActionsPresenter: TagActionsViewOutput {
    func viewDidTapOnDimmingView() {
        
    }
}
