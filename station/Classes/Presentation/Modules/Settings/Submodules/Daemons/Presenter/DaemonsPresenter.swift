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
        bind(advertisement.isOn, fire: false) { (observer, isOn) in
            observer.settings.isAdvertisementDaemonOn = isOn ?? true
        }
        
        let connection = DaemonsViewModel()
        connection.type = .connection
        connection.isOn.value = settings.isConnectionDaemonOn
        bind(connection.isOn, fire: false) { (observer, isOn) in
            observer.settings.isConnectionDaemonOn = isOn ?? true
        }
        
        view.viewModels = [advertisement, connection]
    }
}

extension DaemonsPresenter: DaemonsViewOutput {
    
}
