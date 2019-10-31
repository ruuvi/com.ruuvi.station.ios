import Foundation

class TagActionsPresenter: TagActionsModuleInput {
    weak var view: TagActionsViewInput!
    var router: TagActionsRouterInput!
    var gattService: GATTService!
    
    func configure(uuid: String) {
        view.viewModel = TagActionsViewModel(uuid: uuid)
    }
    
    func configure(isConnectable: Bool) {
        view.viewModel.isSyncEnabled.value = isConnectable
    }
}

extension TagActionsPresenter: TagActionsViewOutput {
    func viewDidLoad() {
        
    }
    
    func viewDidAppear() {
        
    }
    
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
    
    func viewDidAskToClear() {
        
    }
    
    func viewDidAskToSync() {
//        let op = gattService.syncLogs(with: uuid)
//        op.on(failure: { [weak self] (error) in
//            self?.errorPresenter.present(error: error)
//        })
    }
    
    func viewDidAskToExport() {
        
    }
}
