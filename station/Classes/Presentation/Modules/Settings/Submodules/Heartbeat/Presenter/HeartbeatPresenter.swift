import Foundation
import RuuviLocal

class HeartbeatPresenter: NSObject, HeartbeatModuleInput {
    weak var view: HeartbeatViewInput!
    var router: HeartbeatRouterInput!
    var settings: RuuviLocalSettings!

    func configure() {
        let viewModel = HeartbeatViewModel()
        viewModel.bgScanningState.value = settings.saveHeartbeats
        viewModel.bgScanningInterval.value = settings.saveHeartbeatsIntervalMinutes

        bind(viewModel.bgScanningState, fire: false) { observer, saveHeartbeats in
            observer.settings.saveHeartbeats = saveHeartbeats.bound
        }

        bind(viewModel.bgScanningInterval, fire: false) { observer, saveHeartbeatsInterval in
            observer.settings.saveHeartbeatsIntervalMinutes = saveHeartbeatsInterval.bound
        }

        view.viewModel = viewModel
    }
}

extension HeartbeatPresenter: HeartbeatViewOutput {

}
