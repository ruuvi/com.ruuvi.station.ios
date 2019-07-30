import Foundation

class WebTagSettingsPresenter: WebTagSettingsModuleInput {
    weak var view: WebTagSettingsViewInput!
    var router: WebTagSettingsRouterInput!
    
    private var webTag: WebTagRealm!
    
    func configure(webTag: WebTagRealm) {
        self.webTag = webTag
    }
}

extension WebTagSettingsPresenter: WebTagSettingsViewOutput {
    func viewDidAskToDismiss() {
        router.dismiss()
    }
}
