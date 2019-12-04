import Foundation

class HeartbeatPresenter: NSObject, HeartbeatModuleInput {
    weak var view: HeartbeatViewInput!
    var router: HeartbeatRouterInput!
    var settings: Settings!

    func configure() {
        let viewModel = HeartbeatViewModel()
        viewModel.presentConnectionNotifications.value = settings.presentConnectionNotifications
        viewModel.saveHeartbeats.value = settings.saveHeartbeats
        viewModel.saveHeartbeatsInterval.value = settings.saveHeartbeatsIntervalMinutes
        viewModel.readRSSI.value = settings.readRSSI
        viewModel.readRSSIInterval.value = settings.readRSSIIntervalSeconds

        bind(viewModel.presentConnectionNotifications, fire: false) { observer, presentConnectionNotifications in
            observer.settings.presentConnectionNotifications = presentConnectionNotifications.bound
        }

        bind(viewModel.saveHeartbeats, fire: false) { observer, saveHeartbeats in
            observer.settings.saveHeartbeats = saveHeartbeats.bound
        }

        bind(viewModel.saveHeartbeatsInterval, fire: false) { observer, saveHeartbeatsInterval in
            observer.settings.saveHeartbeatsIntervalMinutes = saveHeartbeatsInterval.bound
        }

        bind(viewModel.readRSSI, fire: false) { observer, readRSSI in
            observer.settings.readRSSI = readRSSI.bound
        }

        bind(viewModel.readRSSIInterval, fire: false) { observer, readRSSIInterval in
            observer.settings.readRSSIIntervalSeconds = readRSSIInterval.bound
        }

        view.viewModel = viewModel
    }
}

extension HeartbeatPresenter: HeartbeatViewOutput {

}
