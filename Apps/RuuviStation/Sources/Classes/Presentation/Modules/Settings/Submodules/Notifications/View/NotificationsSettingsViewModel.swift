import Foundation
import RuuviOntology

enum NotificationsSettingsConfigType {
    case switcher
    case plain
}

enum NotificationsSettingsType {
    case email
    case push
    case limitAlert
    case alertSound
}

class NotificationsSettingsViewModel: Identifiable {
    var id = UUID().uuidString

    var title: String?
    var subtitle: String?
    var configType: Observable<NotificationsSettingsConfigType?> =
        .init()
    var settingsType: Observable<NotificationsSettingsType?> =
        .init()
    // Value for switcher type
    var boolean: Observable<Bool?> = .init()
    var hideStatusLabel: Observable<Bool?> = .init()
    // Value for plain type
    var value: Observable<String?> = .init()
}
