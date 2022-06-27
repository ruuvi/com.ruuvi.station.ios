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
    let batteryNeedsReplacement: Observable<Bool?> = Observable<Bool?>()
    let accelerationX: Observable<Double?> = Observable<Double?>()
    let accelerationY: Observable<Double?> = Observable<Double?>()
    let accelerationZ: Observable<Double?> = Observable<Double?>()
    let version: Observable<Int?> = Observable<Int?>()
    let firmwareVersion: Observable<String?> = Observable<String?>()
    let movementCounter: Observable<Int?> = Observable<Int?>()
    let measurementSequenceNumber: Observable<Int?> = Observable<Int?>()
    let txPower: Observable<Int?> = Observable<Int?>()
    let isConnectable: Observable<Bool?> = Observable<Bool?>()
    let isConnected: Observable<Bool?> = Observable<Bool?>()
    let isNetworkConnected: Observable<Bool?> = Observable<Bool?>()
    let keepConnection: Observable<Bool?> = Observable<Bool?>()
    let isConnectionSectionEnabled: Observable<Bool?> = Observable<Bool?>()
    let isConnectionSwitchEnabled: Observable<Bool?> = Observable<Bool?>()
    let isPushNotificationsEnabled: Observable<Bool?> = Observable<Bool?>()

    let temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    let humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()
    let pressureUnit: Observable<UnitPressure?> = Observable<UnitPressure?>()

    let isTemperatureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let temperatureAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let temperatureLowerBound: Observable<Temperature?> = Observable<Temperature?>(Temperature(-40, unit: .celsius))
    let temperatureUpperBound: Observable<Temperature?> = Observable<Temperature?>(Temperature(85, unit: .celsius))
    let temperatureAlertDescription: Observable<String?> = Observable<String?>()

    let isRelativeHumidityAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let relativeHumidityAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let relativeHumidityLowerBound: Observable<Double?> = Observable<Double?>(0)
    let relativeHumidityUpperBound: Observable<Double?> = Observable<Double?>(100.0)
    let relativeHumidityAlertDescription: Observable<String?> = Observable<String?>()

    let isHumidityAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let humidityAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let humidityLowerBound: Observable<Humidity?> = Observable<Humidity?>(.init(value: 0, unit: .absolute))
    let humidityUpperBound: Observable<Humidity?> = Observable<Humidity?>(.init(value: 40, unit: .absolute))
    let humidityAlertDescription: Observable<String?> = Observable<String?>()

    let isDewPointAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let dewPointAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let dewPointLowerBound: Observable<Temperature?> = Observable<Temperature?>(Temperature(-40, unit: .celsius))
    let dewPointUpperBound: Observable<Temperature?> = Observable<Temperature?>(Temperature(85, unit: .celsius))
    let dewPointAlertDescription: Observable<String?> = Observable<String?>()

    let isPressureAlertOn: Observable<Bool?> = Observable<Bool?>(false)
    let pressureAlertMutedTill: Observable<Date?> = Observable<Date?>(nil)
    let pressureLowerBound: Observable<Pressure?> = Observable<Pressure?>(Pressure(300, unit: .hectopascals))
    let pressureUpperBound: Observable<Pressure?> = Observable<Pressure?>(Pressure(1100, unit: .hectopascals))
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
    let isOwner: Observable<Bool?> = Observable<Bool?>(false)

    let temperatureOffsetCorrection: Observable<Double?> = Observable<Double?>()
    let humidityOffsetCorrection: Observable<Double?> = Observable<Double?>()
    let pressureOffsetCorrection: Observable<Double?> = Observable<Double?>()

    let humidityOffsetCorrectionVisible: Observable<Bool?> = Observable<Bool?>()
    let pressureOffsetCorrectionVisible: Observable<Bool?> = Observable<Bool?>()

    let canShowUpdateFirmware: Observable<Bool?> = Observable<Bool?>(false)

    let isAlertsEnabled: Observable<Bool?> = Observable<Bool?>(false)

    let isAlertsVisible: Observable<Bool?> = Observable<Bool?>(false)
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
        rssi.value = record.rssi
        let batteryStatusProvider = RuuviTagBatteryStatusProvider()
        batteryNeedsReplacement.value = batteryStatusProvider.batteryNeedsReplacement(temperature: record.temperature,
                                                                          voltage: record.voltage)
    }

    func reset() {
        // TODO:- @Priyonto: This whole block needs to be refactored in good level later
        isTemperatureAlertOn.value = false
        temperatureLowerBound.value = Temperature(-40, unit: .celsius)
        temperatureUpperBound.value = Temperature(85, unit: .celsius)
        temperatureAlertDescription.value = nil

        isHumidityAlertOn.value = false
        humidityLowerBound.value = Humidity(value: 0, unit: .absolute)
        humidityUpperBound.value = Humidity(value: 40, unit: .absolute)
        humidityAlertDescription.value = nil

        isRelativeHumidityAlertOn.value = false
        relativeHumidityLowerBound.value = 0
        relativeHumidityUpperBound.value = 100
        relativeHumidityAlertDescription.value = nil

        isDewPointAlertOn.value = false
        dewPointLowerBound.value = Temperature(-40, unit: .celsius)
        dewPointUpperBound.value = Temperature(85, unit: .celsius)
        dewPointAlertDescription.value = nil

        isPressureAlertOn.value = false
        pressureLowerBound.value = Pressure(300, unit: .hectopascals)
        pressureUpperBound.value = Pressure(1100, unit: .hectopascals)
        pressureAlertDescription.value = nil

        isConnectionAlertOn.value = false
        connectionAlertDescription.value = nil

        isMovementAlertOn.value = false
        movementAlertDescription.value = nil
    }
}
