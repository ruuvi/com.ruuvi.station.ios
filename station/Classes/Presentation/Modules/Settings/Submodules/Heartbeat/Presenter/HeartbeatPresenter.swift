import Foundation

class HeartbeatPresenter: HeartbeatModuleInput {
    weak var view: HeartbeatViewInput!
    var router: HeartbeatRouterInput!

    func configure() {
        
    }
}

extension HeartbeatPresenter: HeartbeatViewOutput {

}
