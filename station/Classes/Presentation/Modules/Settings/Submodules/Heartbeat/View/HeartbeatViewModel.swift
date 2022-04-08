import Foundation

class HeartbeatViewModel {
    var saveHeartbeats = Observable<Bool?>()
    var saveHeartbeatsInterval = Observable<Int?>(1)

    var saveHeartbeatsTitle: String {
        return "Heartbeat.SaveHeartbeats.title".localized()
    }
}
