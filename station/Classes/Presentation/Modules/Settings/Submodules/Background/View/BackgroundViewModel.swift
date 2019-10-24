import Foundation

class BackgroundViewModel: Identifiable {
    var id: String { get { uuid }}
    var uuid: String
    var name = Observable<String?>()
    var keepConnection = Observable<Bool?>()
    var presentConnectionNotifications = Observable<Bool?>()
    var saveHeartbeats = Observable<Bool?>()
    var saveHeartbeatsInterval = Observable<Int?>(1)
    
    var presentNotificationsTitle: String {
        return "Background.PresentNotifications.title".localized()
    }
    var keepConnectionTitle: String {
        return "Background.KeepConnection.title".localized()
    }
    var saveHeartbeatsTitle: String {
        return "Background.SaveHeartbeats.title".localized()
    }
    
    init(uuid: String) {
        self.uuid = uuid
    }
}

