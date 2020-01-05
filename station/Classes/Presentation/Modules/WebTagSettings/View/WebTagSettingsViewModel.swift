import UIKit

struct WebTagSettingsViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let name: Observable<String?> = Observable<String?>()
    let uuid: Observable<String?> = Observable<String?>()
    let location: Observable<Location?> = Observable<Location?>()

    let isLocationAuthorizedAlways: Observable<Bool?> = Observable<Bool?>(false)
    let isPushNotificationsEnabled: Observable<Bool?> = Observable<Bool?>()

    let temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    let humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()

    let isTemperatureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let celsiusLowerBound: Observable<Double?> = Observable<Double?>(-40)
    let celsiusUpperBound: Observable<Double?> = Observable<Double?>(85)
    let temperatureAlertDescription: Observable<String?> = Observable<String?>()

    let isRelativeHumidityAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let relativeHumidityLowerBound: Observable<Double?> = Observable<Double?>(0)
    let relativeHumidityUpperBound: Observable<Double?> = Observable<Double?>(100)
    let relativeHumidityAlertDescription: Observable<String?> = Observable<String?>()

}
