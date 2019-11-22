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
    let temperatureAlertInterval: Observable<TimeInterval?> = Observable<TimeInterval?>()
    let isPushNotificationsEnabled: Observable<Bool?> = Observable<Bool?>()
    
    let temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    let isTemperatureAlertOn: Observable<Bool?> = Observable<Bool?>()
    let celsiusLowerBound: Observable<Double?> = Observable<Double?>()
    let celsiusUpperBound: Observable<Double?> = Observable<Double?>()
}
