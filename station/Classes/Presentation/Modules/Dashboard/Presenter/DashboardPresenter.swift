import Foundation

class DashboardPresenter: DashboardModuleInput {
    weak var view: DashboardViewInput!
    var router: DashboardRouterInput!
}

extension DashboardPresenter: DashboardViewOutput {
    
}
