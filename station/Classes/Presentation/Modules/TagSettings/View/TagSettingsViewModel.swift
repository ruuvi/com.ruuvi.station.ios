import UIKit

struct TagSettingsViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let name: Observable<String?> = Observable<String?>()
    let uuid: Observable<String?> = Observable<String?>()
    let mac: Observable<String?> = Observable<String?>()
    let humidity: Observable<Humidity?> = Observable<Humidity?>()
    let temperature: Observable<Temperature?> = Observable<Temperature?>()
    let humidityOffset: Observable<Double?> = Observable<Double?>()
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

    let isConnectionAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let connectionAlertDescription: Observable<String?> = Observable<String?>()

    let isMovementAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let movementAlertDescription: Observable<String?> = Observable<String?>()

    func updateRecord(_ record: RuuviTagSensorRecord) {
        humidity.value = record.humidity
        temperature.value = record.temperature
        voltage.value = record.voltage?.value
        accelerationX.value = record.acceleration?.x.value
        accelerationY.value = record.acceleration?.y.value
        accelerationZ.value = record.acceleration?.z.value
        movementCounter.value = record.movementCounter
        measurementSequenceNumber.value = record.measurementSequenceNumber
        txPower.value = record.txPower
    }
}
