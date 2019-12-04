import Foundation

class HeartbeatPresenter: HeartbeatModuleInput {
    weak var view: HeartbeatViewInput!
    var router: HeartbeatRouterInput!
}

extension HeartbeatPresenter: HeartbeatViewOutput {

}
