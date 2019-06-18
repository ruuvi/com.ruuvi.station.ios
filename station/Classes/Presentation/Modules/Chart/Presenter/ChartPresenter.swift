import Foundation

class ChartPresenter: ChartModuleInput {
    weak var view: ChartViewInput!
    var router: ChartRouterInput!
}

extension ChartPresenter: ChartViewOutput {
    
}
