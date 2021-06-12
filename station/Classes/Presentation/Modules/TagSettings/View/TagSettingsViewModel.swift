import UIKit
import RuuviOntology

struct TagSettingsViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let isUploadingBackground: Observable<Bool?> = Observable<Bool?>()
    let uploadingBackgroundPercentage: Observable<Double?> = Observable<Double?>()
    let name: Observable<String?> = Observable<String?>()
    let uuid: Observable<String?> = Observable<String?>()
    let mac: Observable<String?> = Observable<String?>()
    let rssi: Observable<Int?> = Observable<Int?>()
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
    let isNetworkConnected: Observable<Bool?> = Observable<Bool?>()
    let keepConnection: Observable<Bool?> = Observable<Bool?>()
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

    let isConnectionAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let connectionAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let connectionAlertDescription: Observable<String?> = Observable<String?>()

    let isMovementAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let movementAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let movementAlertDescription: Observable<String?> = Observable<String?>()

    let isAuthorized: Observable<Bool?> = Observable<Bool?>(true)
    let canClaimTag: Observable<Bool?> = Observable<Bool?>(false)
    let canShareTag: Observable<Bool?> = Observable<Bool?>(false)
    let isClaimedTag: Observable<Bool?> = Observable<Bool?>(false)
    let owner: Observable<String?> = Observable<String?>()

    let temperatureOffsetCorrection: Observable<Double?> = Observable<Double?>()
    let humidityOffsetCorrection: Observable<Double?> = Observable<Double?>()
    let pressureOffsetCorrection: Observable<Double?> = Observable<Double?>()

    let canShowUpdateFirmware: Observable<Bool?> = Observable<Bool?>(false)

    let isAlertsEnabled: Observable<Bool?> = Observable<Bool?>(false)
    let isPNAlertsAvailiable: Observable<Bool?> = Observable<Bool?>(false)
    let isCloudAlertsAvailable: Observable<Bool?> = Observable<Bool?>(false)

    var source: Observable<RuuviTagSensorRecordSource?> = Observable<RuuviTagSensorRecordSource?>()

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
        source.value = record.source
    }
}
