import Foundation
import RuuviNotifier
import Localize_Swift

struct RuuviServiceNotifierTitlesImpl: RuuviServiceNotifierTitles {
    let lowTemperature = "LocalNotificationsManager.LowTemperature.title".localized()
    let highTemperature = "LocalNotificationsManager.HighTemperature.title".localized()
    let lowHumidity = "LocalNotificationsManager.LowHumidity.title".localized()
    let highHumidity = "LocalNotificationsManager.HighHumidity.title".localized()
    let lowDewPoint = "LocalNotificationsManager.LowDewPoint.title".localized()
    let highDewPoint = "LocalNotificationsManager.HighDewPoint.title".localized()
    let lowPressure = "LocalNotificationsManager.LowPressure.title".localized()
    let highPressure = "LocalNotificationsManager.HighPressure.title".localized()
    let didMove = "LocalNotificationsManager.DidMove.title".localized()
}
