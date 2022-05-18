import Foundation
import RuuviLocal

class HeartbeatPresenter: NSObject, HeartbeatModuleInput {
    weak var view: HeartbeatViewInput!
    var router: HeartbeatRouterInput!
    var settings: RuuviLocalSettings!

    func configure() {
        let viewModel = HeartbeatViewModel()
        viewModel.saveHeartbeats.value = settings.saveHeartbeats
        viewModel.saveHeartbeatsInterval.value = settings.saveHeartbeatsIntervalMinutes

        bind(viewModel.saveHeartbeats, fire: false) { observer, saveHeartbeats in
            observer.settings.saveHeartbeats = saveHeartbeats.bound
        }

        bind(viewModel.saveHeartbeatsInterval, fire: false) { observer, saveHeartbeatsInterval in
            observer.settings.saveHeartbeatsIntervalMinutes = saveHeartbeatsInterval.bound
        }

        view.viewModel = viewModel
    }
}

extension HeartbeatPresenter: HeartbeatViewOutput {

}
