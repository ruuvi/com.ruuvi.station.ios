import UIKit

struct WebTagSettingsViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let name: Observable<String?> = Observable<String?>()
    let uuid: Observable<String?> = Observable<String?>()
    let location: Observable<Location?> = Observable<Location?>()

    let isLocationAuthorizedAlways: Observable<Bool?> = Observable<Bool?>(false)
    let isPushNotificationsEnabled: Observable<Bool?> = Observable<Bool?>()

    let currentTemperature: Observable<Temperature?> = Observable<Temperature?>()

    let temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    let humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()
    let pressureUnit: Observable<UnitPressure?> = Observable<UnitPressure?>()

    let isTemperatureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let celsiusLowerBound: Observable<Double?> = Observable<Double?>(-40)
    let celsiusUpperBound: Observable<Double?> = Observable<Double?>(85)
    let temperatureAlertDescription: Observable<String?> = Observable<String?>()

    let isHumidityAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let humidityLowerBound: Observable<Humidity?> = Observable<Humidity?>(.init(value: 0, unit: .absolute))
    let humidityUpperBound: Observable<Humidity?> = Observable<Humidity?>(.init(value: 40, unit: .absolute))
    let humidityAlertDescription: Observable<String?> = Observable<String?>()

    let isPressureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let pressureLowerBound: Observable<Double?> = Observable<Double?>(300)
    let pressureUpperBound: Observable<Double?> = Observable<Double?>(1100)
    let pressureAlertDescription: Observable<String?> = Observable<String?>()
}
