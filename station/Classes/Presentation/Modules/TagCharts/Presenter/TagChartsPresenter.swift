import Foundation

class TagChartsPresenter: TagChartsModuleInput {
    weak var view: TagChartsViewInput!
    var router: TagChartsRouterInput!
    
    private var ruuviTag: RuuviTagRealm!
    
    func configure(ruuviTag: RuuviTagRealm) {
        self.ruuviTag = ruuviTag
    }
}

extension TagChartsPresenter: TagChartsViewOutput {
    func viewDidTriggerDashboard() {
        router.dismiss()
    }
}
