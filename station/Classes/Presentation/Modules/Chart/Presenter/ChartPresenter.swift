import Foundation

class ChartPresenter: ChartModuleInput {
    weak var view: ChartViewInput!
    var router: ChartRouterInput!
    
    private var ruuviTag: RuuviTagRealm!
    
    func configure(ruuviTag: RuuviTagRealm) {
        self.ruuviTag = ruuviTag
    }
}

extension ChartPresenter: ChartViewOutput {
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
}
