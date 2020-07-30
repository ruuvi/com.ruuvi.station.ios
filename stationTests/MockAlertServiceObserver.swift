import Foundation
@testable import station

class MockAlertServiceObserver: AlertServiceObserver {
    var service: AlertService? = .none
    var isTriggered: Bool? = .none
    var uuid: String? = .none

    func alert(service: AlertService, isTriggered: Bool, for uuid: String) {
        self.service = service
        self.isTriggered = isTriggered
        self.uuid = uuid
    }
}
