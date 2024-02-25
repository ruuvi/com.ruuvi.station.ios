import Foundation
import RuuviLocal

class HeartbeatPresenter: NSObject, HeartbeatModuleInput {
    weak var view: HeartbeatViewInput!
    var router: HeartbeatRouterInput!
    var settings: RuuviLocalSettings!
    var connectionPersistence: RuuviLocalConnections!

    func configure() {
        let viewModel = HeartbeatViewModel()
        viewModel.hideSwitchStatusLabel.value = !settings.showSwitchStatusLabel
        viewModel.bgScanningState.value = settings.saveHeartbeats
        viewModel.bgScanningInterval.value = settings.saveHeartbeatsIntervalMinutes

        bind(viewModel.bgScanningState, fire: false) { observer, saveHeartbeats in
            guard let saveHeartbeats else { return }
            observer.settings.saveHeartbeats = saveHeartbeats
            if !saveHeartbeats {
                observer.connectionPersistence.unpairAllConnection()
            }
        }

        bind(viewModel.bgScanningInterval, fire: false) { observer, saveHeartbeatsInterval in
            observer.settings.saveHeartbeatsIntervalMinutes = saveHeartbeatsInterval.bound
        }

        view.viewModel = viewModel
    }
}

extension HeartbeatPresenter: HeartbeatViewOutput {}
