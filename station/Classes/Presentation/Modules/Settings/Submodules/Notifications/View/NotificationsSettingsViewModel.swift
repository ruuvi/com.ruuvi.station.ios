import Foundation
import RuuviOntology

enum NotificationsSettingsConfigType {
    case switcher
    case plain
}

enum NotificationsSettingsType {
    case email
    case push
    case alertSound
}

class NotificationsSettingsViewModel: Identifiable {
    var id = UUID().uuidString

    var title: String?
    var subtitle: String?
    var configType: Observable<NotificationsSettingsConfigType?> =
        Observable<NotificationsSettingsConfigType?>()
    var settingsType: Observable<NotificationsSettingsType?> =
        Observable<NotificationsSettingsType?>()
    // Value for switcher type
    var boolean: Observable<Bool?> = Observable<Bool?>()
    // Value for plain type
    var value: Observable<String?> = Observable<String?>()
}
