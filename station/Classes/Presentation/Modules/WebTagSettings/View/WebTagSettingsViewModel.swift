import UIKit
import RuuviOntology

struct WebTagSettingsViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let name: Observable<String?> = Observable<String?>()
    let uuid: Observable<String?> = Observable<String?>()
    let location: Observable<Location?> = Observable<Location?>()
    let temperature: Observable<Temperature?> = Observable<Temperature?>()

    let isLocationAuthorizedAlways: Observable<Bool?> = Observable<Bool?>(false)
    let isPushNotificationsEnabled: Observable<Bool?> = Observable<Bool?>()

    let temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    let humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()
    let pressureUnit: Observable<UnitPressure?> = Observable<UnitPressure?>()

    let isTemperatureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let temperatureAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let temperatureLowerBound: Observable<Temperature?> = Observable<Temperature?>()
    let temperatureUpperBound: Observable<Temperature?> = Observable<Temperature?>()
    let temperatureAlertDescription: Observable<String?> = Observable<String?>()

    let isRelativeHumidityAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let relativeHumidityAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let relativeHumidityLowerBound: Observable<Double?> = Observable<Double?>()
    let relativeHumidityUpperBound: Observable<Double?> = Observable<Double?>()
    let relativeHumidityAlertDescription: Observable<String?> = Observable<String?>()

    let isHumidityAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let humidityAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let humidityLowerBound: Observable<Humidity?> = Observable<Humidity?>(.init(value: 0, unit: .absolute))
    let humidityUpperBound: Observable<Humidity?> = Observable<Humidity?>(.init(value: 40, unit: .absolute))
    let humidityAlertDescription: Observable<String?> = Observable<String?>()

    let isDewPointAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let dewPointAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let dewPointLowerBound: Observable<Temperature?> = Observable<Temperature?>()
    let dewPointUpperBound: Observable<Temperature?> = Observable<Temperature?>()
    let dewPointAlertDescription: Observable<String?> = Observable<String?>()

    let isPressureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let pressureAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let pressureLowerBound: Observable<Pressure?> = Observable<Pressure?>()
    let pressureUpperBound: Observable<Pressure?> = Observable<Pressure?>()
    let pressureAlertDescription: Observable<String?> = Observable<String?>()
}
