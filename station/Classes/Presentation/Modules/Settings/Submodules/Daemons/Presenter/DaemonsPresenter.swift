import Foundation
import Combine

enum DaemonType {
    case advertisement
    case connection
}

class DaemonsPresenter: NSObject, DaemonsModuleInput {
    weak var view: DaemonsViewInput!
    var router: DaemonsRouterInput!
    var settings: Settings!
    
    func configure() {
        let advertisement = DaemonsViewModel()
        advertisement.type = .advertisement
        advertisement.isOn.value = settings.isAdvertisementDaemonOn
        advertisement.interval.value = settings.advertisementDaemonIntervalMinutes
        bind(advertisement.isOn, fire: false) { (observer, isOn) in
            observer.settings.isAdvertisementDaemonOn = isOn ?? true
        }
        bind(advertisement.interval, fire: false) { observer, interval in
            observer.settings.advertisementDaemonIntervalMinutes = interval ?? 1
        }
        
        let connection = DaemonsViewModel()
        connection.type = .connection
        connection.isOn.value = settings.isConnectionDaemonOn
        connection.interval.value = settings.connectionDaemonIntervalMinutes
        bind(connection.isOn, fire: false) { (observer, isOn) in
            observer.settings.isConnectionDaemonOn = isOn ?? true
        }
        bind(connection.interval, fire: false) { observer, interval in
            observer.settings.connectionDaemonIntervalMinutes = interval ?? 1
        }
        
        view.viewModels = [advertisement, connection]
    }
}

extension DaemonsPresenter: DaemonsViewOutput {
    
}
