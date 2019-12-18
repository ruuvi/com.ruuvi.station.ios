import UIKit

struct TagSettingsViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let name: Observable<String?> = Observable<String?>()
    let uuid: Observable<String?> = Observable<String?>()
    let mac: Observable<String?> = Observable<String?>()
    let relativeHumidity: Observable<Double?> = Observable<Double?>()
    let humidityOffset: Observable<Double?> = Observable<Double?>()
    let humidityOffsetDate: Observable<Date?> = Observable<Date?>()
    let voltage: Observable<Double?> = Observable<Double?>()
    let accelerationX: Observable<Double?> = Observable<Double?>()
    let accelerationY: Observable<Double?> = Observable<Double?>()
    let accelerationZ: Observable<Double?> = Observable<Double?>()
    let version: Observable<Int?> = Observable<Int?>()
    let movementCounter: Observable<Int?> = Observable<Int?>()
    let measurementSequenceNumber: Observable<Int?> = Observable<Int?>()
    let txPower: Observable<Int?> = Observable<Int?>()
    let isConnectable: Observable<Bool?> = Observable<Bool?>()
    let isConnected: Observable<Bool?> = Observable<Bool?>()
    let keepConnection: Observable<Bool?> = Observable<Bool?>()
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

    let isAbsoluteHumidityAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let absoluteHumidityLowerBound: Observable<Double?> = Observable<Double?>(0)
    let absoluteHumidityUpperBound: Observable<Double?> = Observable<Double?>(40)
    let absoluteHumidityAlertDescription: Observable<String?> = Observable<String?>()

    let isDewPointAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let dewPointCelsiusLowerBound: Observable<Double?> = Observable<Double?>(-40)
    let dewPointCelsiusUpperBound: Observable<Double?> = Observable<Double?>(85)
    let dewPointAlertDescription: Observable<String?> = Observable<String?>()

    let isPressureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let pressureLowerBound: Observable<Double?> = Observable<Double?>(300)
    let pressureUpperBound: Observable<Double?> = Observable<Double?>(1100)
    let pressureAlertDescription: Observable<String?> = Observable<String?>()

    let isConnectionAlertOn: Observable<Bool?> = Observable<Bool?>(false)
}
