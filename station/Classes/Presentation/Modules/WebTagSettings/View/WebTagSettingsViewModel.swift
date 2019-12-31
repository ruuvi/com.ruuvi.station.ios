import UIKit

struct WebTagSettingsViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let name: Observable<String?> = Observable<String?>()
    let uuid: Observable<String?> = Observable<String?>()
    let location: Observable<Location?> = Observable<Location?>()

    let isPushNotificationsEnabled: Observable<Bool?> = Observable<Bool?>()
    let temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()

    let isTemperatureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let celsiusLowerBound: Observable<Double?> = Observable<Double?>(-40)
    let celsiusUpperBound: Observable<Double?> = Observable<Double?>(85)
    let temperatureAlertDescription: Observable<String?> = Observable<String?>()

    let isLocationAuthorizedAlways: Observable<Bool?> = Observable<Bool?>(false)
}
