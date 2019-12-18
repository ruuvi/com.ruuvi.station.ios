import Foundation

class HeartbeatViewModel {
    var saveHeartbeats = Observable<Bool?>()
    var saveHeartbeatsInterval = Observable<Int?>(1)
    var readRSSI = Observable<Bool?>()
    var readRSSIInterval = Observable<Int?>(5)

    var saveHeartbeatsTitle: String {
        return "Heartbeat.SaveHeartbeats.title".localized()
    }
    var readRSSITitle: String {
        return "Heartbeat.readRSSITitle.title".localized()
    }

}
