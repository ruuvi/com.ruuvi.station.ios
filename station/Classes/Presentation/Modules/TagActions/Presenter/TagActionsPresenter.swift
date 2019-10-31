import Foundation

class TagActionsPresenter: TagActionsModuleInput {
    weak var view: TagActionsViewInput!
    var router: TagActionsRouterInput!
    var gattService: GATTService!
    var errorPresenter: ErrorPresenter!
    var ruuviTagService: RuuviTagService!
    var exportService: ExportService!
    
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
        view.showClearConfirmationDialog()
    }
    
    func viewDidAskToSync() {
        view.showSyncConfirmationDialog()
    }
    
    func viewDidAskToExport() {
        exportService.csvLog(for: view.viewModel.uuid).on(success: { [weak self] url in
            self?.view.showExportSheet(with: url)
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
    
    func viewDidConfirmToSync() {
        let op = gattService.syncLogs(with: view.viewModel.uuid)
        op.on(failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
    
    func viewDidConfirmToClear() {
        let op = ruuviTagService.clearHistory(uuid: view.viewModel.uuid)
        op.on(failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
    
}
