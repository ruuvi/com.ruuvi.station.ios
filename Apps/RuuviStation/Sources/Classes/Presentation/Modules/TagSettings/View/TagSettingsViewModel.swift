import RuuviOntology
import UIKit

struct TagSettingsViewModel {
    let background: Observable<UIImage?> = .init()
    let name: Observable<String?> = .init()
    let uuid: Observable<String?> = .init()
    let mac: Observable<String?> = .init()
    let rssi: Observable<Int?> = .init()
    let humidity: Observable<Humidity?> = .init()
    let temperature: Observable<Temperature?> = .init()
    let humidityOffset: Observable<Double?> = .init()
    let voltage: Observable<Double?> = .init()
    let batteryNeedsReplacement: Observable<Bool?> = .init()
    let accelerationX: Observable<Double?> = .init()
    let accelerationY: Observable<Double?> = .init()
    let accelerationZ: Observable<Double?> = .init()
    let version: Observable<Int?> = .init()
    let firmwareVersion: Observable<String?> = .init()
    let movementCounter: Observable<Int?> = .init()
    let measurementSequenceNumber: Observable<Int?> = .init()
    let txPower: Observable<Int?> = .init()
    let isConnectable: Observable<Bool?> = .init()
    let isConnected: Observable<Bool?> = .init()
    let isNetworkConnected: Observable<Bool?> = .init()
    let keepConnection: Observable<Bool?> = .init()
    let isPushNotificationsEnabled: Observable<Bool?> = .init()

    let temperatureUnit: Observable<TemperatureUnit?> = .init()
    let humidityUnit: Observable<HumidityUnit?> = .init()
    let pressureUnit: Observable<UnitPressure?> = .init()

    let isTemperatureAlertOn: Observable<Bool?> = .init(false)
    let temperatureAlertMutedTill: Observable<Date?> = .init(nil)
    let temperatureLowerBound: Observable<Temperature?> = .init(Temperature(-40, unit: .celsius))
    let temperatureUpperBound: Observable<Temperature?> = .init(Temperature(85, unit: .celsius))
    let temperatureAlertDescription: Observable<String?> = .init()
    let temperatureAlertState: Observable<AlertState?> = .init()

    let isRelativeHumidityAlertOn: Observable<Bool?> = .init(false)
    let relativeHumidityAlertMutedTill: Observable<Date?> = .init(nil)
    let relativeHumidityLowerBound: Observable<Double?> = .init(0)
    let relativeHumidityUpperBound: Observable<Double?> = .init(100.0)
    let relativeHumidityAlertDescription: Observable<String?> = .init()
    let relativeHumidityAlertState: Observable<AlertState?> = .init()

    let isPressureAlertOn: Observable<Bool?> = .init(false)
    let pressureAlertMutedTill: Observable<Date?> = .init(nil)
    let pressureLowerBound: Observable<Pressure?> = .init(Pressure(500, unit: .hectopascals))
    let pressureUpperBound: Observable<Pressure?> = .init(Pressure(1155, unit: .hectopascals))
    let pressureAlertDescription: Observable<String?> = .init()
    let pressureAlertState: Observable<AlertState?> = .init()

    let isSignalAlertOn: Observable<Bool?> = .init(false)
    let signalAlertMutedTill: Observable<Date?> = .init(nil)
    let signalLowerBound: Observable<Double?> = .init(-105)
    let signalUpperBound: Observable<Double?> = .init(0)
    let signalAlertDescription: Observable<String?> = .init()
    let signalAlertState: Observable<AlertState?> = .init()

    let isConnectionAlertOn: Observable<Bool?> = .init(false)
    let connectionAlertMutedTill: Observable<Date?> = .init(nil)
    let connectionAlertDescription: Observable<String?> = .init()
    let connectionAlertState: Observable<AlertState?> = .init()

    let isCloudConnectionAlertOn: Observable<Bool?> = .init(false)
    let cloudConnectionAlertMutedTill: Observable<Date?> = .init(nil)
    let cloudConnectionAlertUnseenDuration: Observable<Double?> = .init()
    let cloudConnectionAlertDescription: Observable<String?> = .init()
    let cloudConnectionAlertState: Observable<AlertState?> = .init()

    let isMovementAlertOn: Observable<Bool?> = .init(false)
    let movementAlertMutedTill: Observable<Date?> = .init(nil)
    let movementAlertDescription: Observable<String?> = .init()
    let movementAlertState: Observable<AlertState?> = .init()

    let isAuthorized: Observable<Bool?> = .init(true)
    let canClaimTag: Observable<Bool?> = .init(false)
    let canShareTag: Observable<Bool?> = .init(false)
    var sharedTo: Observable<[String]?> = .init()
    let isClaimedTag: Observable<Bool?> = .init(false)
    let owner: Observable<String?> = .init()
    let isOwner: Observable<Bool?> = .init(false)
    let ownersPlan: Observable<String?> = .init()
    let isOwnersPlanProPlus: Observable<Bool?> = .init(false)

    let temperatureOffsetCorrection: Observable<Double?> = .init()
    let humidityOffsetCorrection: Observable<Double?> = .init()
    let pressureOffsetCorrection: Observable<Double?> = .init()

    let humidityOffsetCorrectionVisible: Observable<Bool?> = .init()
    let pressureOffsetCorrectionVisible: Observable<Bool?> = .init()

    let isAlertsEnabled: Observable<Bool?> = .init(false)
    let isPNAlertsAvailiable: Observable<Bool?> = .init(false)
    let isCloudAlertsAvailable: Observable<Bool?> = .init(false)
    let isCloudConnectionAlertsAvailable: Observable<Bool?> = .init(false)

    var source: Observable<RuuviTagSensorRecordSource?> = .init()

    var latestMeasurement: Observable<RuuviTagSensorRecord?> = .init()

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
        let batteryStatusProvider = RuuviTagBatteryStatusProvider()
        batteryNeedsReplacement.value = batteryStatusProvider.batteryNeedsReplacement(
            temperature: record.temperature,
            voltage: record.voltage
        )
        latestMeasurement.value = record
    }

    func reset() {
        // TODO: - @Priyonto: This whole block needs to be refactored in good level later
        isTemperatureAlertOn.value = false
        temperatureLowerBound.value = Temperature(-40, unit: .celsius)
        temperatureUpperBound.value = Temperature(85, unit: .celsius)
        temperatureAlertDescription.value = nil

        isRelativeHumidityAlertOn.value = false
        relativeHumidityLowerBound.value = 0
        relativeHumidityUpperBound.value = 100
        relativeHumidityAlertDescription.value = nil

        isPressureAlertOn.value = false
        pressureLowerBound.value = Pressure(500, unit: .hectopascals)
        pressureUpperBound.value = Pressure(1155, unit: .hectopascals)
        pressureAlertDescription.value = nil

        isSignalAlertOn.value = false
        signalLowerBound.value = -105
        signalUpperBound.value = 0
        signalAlertDescription.value = nil

        isConnectionAlertOn.value = false
        connectionAlertDescription.value = nil

        isMovementAlertOn.value = false
        movementAlertDescription.value = nil

        latestMeasurement.value = nil
    }
}
