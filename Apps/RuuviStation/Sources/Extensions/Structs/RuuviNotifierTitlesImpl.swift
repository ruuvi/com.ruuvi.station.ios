import Foundation
import RuuviLocalization
import RuuviNotifier

struct RuuviNotifierTitlesImpl: RuuviNotifierTitles {
    let lowTemperature = RuuviLocalization.LocalNotificationsManager.LowTemperature.title
    let highTemperature = RuuviLocalization.LocalNotificationsManager.HighTemperature.title
    let lowHumidity = RuuviLocalization.LocalNotificationsManager.LowHumidity.title
    let highHumidity = RuuviLocalization.LocalNotificationsManager.HighHumidity.title
    let lowDewPoint = RuuviLocalization.LocalNotificationsManager.LowDewPoint.title
    let highDewPoint = RuuviLocalization.LocalNotificationsManager.HighDewPoint.title
    let lowPressure = RuuviLocalization.LocalNotificationsManager.LowPressure.title
    let highPressure = RuuviLocalization.LocalNotificationsManager.HighPressure.title
    let lowSignal = RuuviLocalization.LocalNotificationsManager.LowSignal.title
    let highSignal = RuuviLocalization.LocalNotificationsManager.HighSignal.title
    let didMove = RuuviLocalization.LocalNotificationsManager.DidMove.title
}
