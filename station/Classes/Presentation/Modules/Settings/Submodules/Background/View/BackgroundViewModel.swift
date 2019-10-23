import Foundation

class BackgroundViewModel: Identifiable {
    var id: String { get { uuid }}
    var uuid: String
    var name = Observable<String?>()
    var keepConnection = Observable<Bool?>()
    var presentConnectionNotifications = Observable<Bool?>()
    
    var presentNotificationsTitle: String {
        return "Background.PresentNotifications.title".localized()
    }
    var keepConnectionTitle: String {
        return "Background.KeepConnection.title".localized()
    }
    
    init(uuid: String) {
        self.uuid = uuid
    }
}

