import Foundation

class WebTagSettingsPresenter: WebTagSettingsModuleInput {
    weak var view: WebTagSettingsViewInput!
    var router: WebTagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    
    private var webTag: WebTagRealm! {
        didSet {
            syncViewModel()
        }
    }
    
    func configure(webTag: WebTagRealm) {
        self.webTag = webTag
    }
}

// MARK: - WebTagSettingsViewOutput
extension WebTagSettingsPresenter: WebTagSettingsViewOutput {
    func viewDidAskToDismiss() {
        router.dismiss()
    }
    
    func viewDidAskToRandomizeBackground() {
        
    }
    
    func viewDidAskToSelectBackground() {
        
    }
}

// MARK: - Private
extension WebTagSettingsPresenter {
    private func syncViewModel() {
        view.viewModel.background.value = backgroundPersistence.background(for: webTag.uuid)
        
        if webTag.name == webTag.provider.displayName {
            view.viewModel.name.value = nil
        } else {
            view.viewModel.name.value = webTag.name
        }

        view.viewModel.uuid.value = webTag.uuid
    }
}
