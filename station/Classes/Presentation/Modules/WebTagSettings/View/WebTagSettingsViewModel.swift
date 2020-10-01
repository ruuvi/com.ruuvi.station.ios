import UIKit

struct WebTagSettingsViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let name: Observable<String?> = Observable<String?>()
    let uuid: Observable<String?> = Observable<String?>()
    let location: Observable<Location?> = Observable<Location?>()
    let temperature: Observable<Temperature?> = Observable<Temperature?>()

    let isLocationAuthorizedAlways: Observable<Bool?> = Observable<Bool?>(false)
    let isPushNotificationsEnabled: Observable<Bool?> = Observable<Bool?>()

    let currentTemperature: Observable<Temperature?> = Observable<Temperature?>()

    let temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    let humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()
    let pressureUnit: Observable<UnitPressure?> = Observable<UnitPressure?>()

    let isTemperatureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let temperatureLowerBound: Observable<Temperature?> = Observable<Temperature?>()
    let temperatureUpperBound: Observable<Temperature?> = Observable<Temperature?>()
    let temperatureAlertDescription: Observable<String?> = Observable<String?>()

    let isHumidityAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let humidityLowerBound: Observable<Humidity?> = Observable<Humidity?>(.init(value: 0, unit: .absolute))
    let humidityUpperBound: Observable<Humidity?> = Observable<Humidity?>(.init(value: 40, unit: .absolute))
    let humidityAlertDescription: Observable<String?> = Observable<String?>()

    let isDewPointAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let dewPointLowerBound: Observable<Temperature?> = Observable<Temperature?>()
    let dewPointUpperBound: Observable<Temperature?> = Observable<Temperature?>()
    let dewPointAlertDescription: Observable<String?> = Observable<String?>()

    let isPressureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let pressureLowerBound: Observable<Pressure?> = Observable<Pressure?>()
    let pressureUpperBound: Observable<Pressure?> = Observable<Pressure?>()
    let pressureAlertDescription: Observable<String?> = Observable<String?>()
}
