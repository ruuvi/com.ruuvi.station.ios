import Foundation

class ChartPresenter: ChartModuleInput {
    weak var view: ChartViewInput!
    var router: ChartRouterInput!
    
    private var ruuviTag: RuuviTagRealm!
    private var type: ChartDataType!
    
    func configure(ruuviTag: RuuviTagRealm, type: ChartDataType) {
        self.ruuviTag = ruuviTag
        self.type = type
    }
}

extension ChartPresenter: ChartViewOutput {
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
}
