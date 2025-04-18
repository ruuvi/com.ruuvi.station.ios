import RuuviOntology
import UIKit

// swiftlint:disable type_body_length
struct TagSettingsViewModel {
    let background: Observable<UIImage?> = .init()
    let name: Observable<String?> = .init()
    let uuid: Observable<String?> = .init()
    let mac: Observable<String?> = .init()
    var serviceUUID: Observable<String?> = .init()
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
    let pm1: Observable<Double?> = .init()
    let pm2_5: Observable<Double?> = .init()
    let pm4: Observable<Double?> = .init()
    let pm10: Observable<Double?> = .init()
    let co2: Observable<Double?> = .init()
    let voc: Observable<Double?> = .init()
    let nox: Observable<Double?> = .init()
    let luminance: Observable<Double?> = .init()
    let dbaAvg: Observable<Double?> = .init()
    let dbaPeak: Observable<Double?> = .init()
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
    let customTemperatureLowerBound: Observable<Temperature?> = .init(Temperature(-55, unit: .celsius))
    let customTemperatureUpperBound: Observable<Temperature?> = .init(Temperature(150, unit: .celsius))
    var showCustomTempAlertBound: Observable<Bool?> = .init()

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

    let isCarbonDioxideAlertOn: Observable<Bool?> = .init(false)
    let carbonDioxideAlertMutedTill: Observable<Date?> = .init(nil)
    let carbonDioxideLowerBound: Observable<Double?> = .init(350)
    let carbonDioxideUpperBound: Observable<Double?> = .init(2500)
    let carbonDioxideAlertDescription: Observable<String?> = .init()
    let carbonDioxideAlertState: Observable<AlertState?> = .init()

    let isPMatter1AlertOn: Observable<Bool?> = .init(false)
    let pMatter1AlertMutedTill: Observable<Date?> = .init(nil)
    let pMatter1LowerBound: Observable<Double?> = .init(0)
    let pMatter1UpperBound: Observable<Double?> = .init(250)
    let pMatter1AlertDescription: Observable<String?> = .init()
    let pMatter1AlertState: Observable<AlertState?> = .init()

    let isPMatter2_5AlertOn: Observable<Bool?> = .init(false)
    let pMatter2_5AlertMutedTill: Observable<Date?> = .init(nil)
    let pMatter2_5LowerBound: Observable<Double?> = .init(0)
    let pMatter2_5UpperBound: Observable<Double?> = .init(250)
    let pMatter2_5AlertDescription: Observable<String?> = .init()
    let pMatter2_5AlertState: Observable<AlertState?> = .init()

    let isPMatter4AlertOn: Observable<Bool?> = .init(false)
    let pMatter4AlertMutedTill: Observable<Date?> = .init(nil)
    let pMatter4LowerBound: Observable<Double?> = .init(0)
    let pMatter4UpperBound: Observable<Double?> = .init(250)
    let pMatter4AlertDescription: Observable<String?> = .init()
    let pMatter4AlertState: Observable<AlertState?> = .init()

    let isPMatter10AlertOn: Observable<Bool?> = .init(false)
    let pMatter10AlertMutedTill: Observable<Date?> = .init(nil)
    let pMatter10LowerBound: Observable<Double?> = .init(0)
    let pMatter10UpperBound: Observable<Double?> = .init(250)
    let pMatter10AlertDescription: Observable<String?> = .init()
    let pMatter10AlertState: Observable<AlertState?> = .init()

    let isVOCAlertOn: Observable<Bool?> = .init(false)
    let vocAlertMutedTill: Observable<Date?> = .init(nil)
    let vocLowerBound: Observable<Double?> = .init(0)
    let vocUpperBound: Observable<Double?> = .init(500)
    let vocAlertDescription: Observable<String?> = .init()
    let vocAlertState: Observable<AlertState?> = .init()

    let isNOXAlertOn: Observable<Bool?> = .init(false)
    let noxAlertMutedTill: Observable<Date?> = .init(nil)
    let noxLowerBound: Observable<Double?> = .init(0)
    let noxUpperBound: Observable<Double?> = .init(500)
    let noxAlertDescription: Observable<String?> = .init()
    let noxAlertState: Observable<AlertState?> = .init()

    let isSoundAlertOn: Observable<Bool?> = .init(false)
    let soundAlertMutedTill: Observable<Date?> = .init(nil)
    let soundLowerBound: Observable<Double?> = .init(0)
    let soundUpperBound: Observable<Double?> = .init(127)
    let soundAlertDescription: Observable<String?> = .init()
    let soundAlertState: Observable<AlertState?> = .init()

    let isLuminosityAlertOn: Observable<Bool?> = .init(false)
    let luminosityAlertMutedTill: Observable<Date?> = .init(nil)
    let luminosityLowerBound: Observable<Double?> = .init(0)
    let luminosityUpperBound: Observable<Double?> = .init(10000)
    let luminosityAlertDescription: Observable<String?> = .init()
    let luminosityAlertState: Observable<AlertState?> = .init()

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

    let hideSwitchStatusLabel: Observable<Bool?> = .init(false)

    func updateRecord(_ record: RuuviTagSensorRecord) {
        version.value = record.version
        humidity.value = record.humidity
        temperature.value = record.temperature
        voltage.value = record.voltage?.value
        accelerationX.value = record.acceleration?.x.value
        accelerationY.value = record.acceleration?.y.value
        accelerationZ.value = record.acceleration?.z.value
        movementCounter.value = record.movementCounter
        measurementSequenceNumber.value = record.measurementSequenceNumber
        txPower.value = record.txPower
        pm1.value = record.pm1
        pm2_5.value = record.pm2_5
        pm4.value = record.pm4
        pm10.value = record.pm10
        co2.value = record.co2
        voc.value = record.voc
        nox.value = record.nox
        luminance.value = record.luminance
        dbaAvg.value = record.dbaAvg
        dbaPeak.value = record.dbaPeak
        source.value = record.source
        let batteryStatusProvider = RuuviTagBatteryStatusProvider()
        batteryNeedsReplacement.value = batteryStatusProvider.batteryNeedsReplacement(
            temperature: record.temperature,
            voltage: record.voltage
        )
        latestMeasurement.value = record
    }

    // swiftlint:disable:next function_body_length
    func reset() {
        isTemperatureAlertOn.value = false
        temperatureLowerBound.value = Temperature(
            TagSettingsAlertConstants.Temperature.lowerBound,
            unit: .celsius
        )
        temperatureUpperBound.value = Temperature(
            TagSettingsAlertConstants.Temperature.upperBound,
            unit: .celsius
        )
        temperatureAlertDescription.value = nil
        showCustomTempAlertBound.value = false

        isRelativeHumidityAlertOn.value = false
        relativeHumidityLowerBound.value = TagSettingsAlertConstants.RelativeHumidity.lowerBound
        relativeHumidityUpperBound.value = TagSettingsAlertConstants.RelativeHumidity.upperBound
        relativeHumidityAlertDescription.value = nil

        isPressureAlertOn.value = false
        pressureLowerBound.value = Pressure(
            TagSettingsAlertConstants.Pressure.lowerBound,
            unit: .hectopascals
        )
        pressureUpperBound.value = Pressure(
            TagSettingsAlertConstants.Pressure.upperBound,
            unit: .hectopascals
        )
        pressureAlertDescription.value = nil

        isSignalAlertOn.value = false
        signalLowerBound.value = TagSettingsAlertConstants.Signal.lowerBound
        signalUpperBound.value = TagSettingsAlertConstants.Signal.upperBound
        signalAlertDescription.value = nil

        isConnectionAlertOn.value = false
        connectionAlertDescription.value = nil

        isMovementAlertOn.value = false
        movementAlertDescription.value = nil

        isCarbonDioxideAlertOn.value = false
        carbonDioxideLowerBound.value = TagSettingsAlertConstants.CarbonDioxide.lowerBound
        carbonDioxideUpperBound.value = TagSettingsAlertConstants.CarbonDioxide.upperBound
        carbonDioxideAlertDescription.value = nil

        isPMatter1AlertOn.value = false
        pMatter1LowerBound.value = TagSettingsAlertConstants.ParticulateMatter.lowerBound
        pMatter1UpperBound.value = TagSettingsAlertConstants.ParticulateMatter.upperBound
        pMatter1AlertDescription.value = nil

        isPMatter2_5AlertOn.value = false
        pMatter2_5LowerBound.value = TagSettingsAlertConstants.ParticulateMatter.lowerBound
        pMatter2_5UpperBound.value = TagSettingsAlertConstants.ParticulateMatter.upperBound
        pMatter2_5AlertDescription.value = nil

        isPMatter4AlertOn.value = false
        pMatter4LowerBound.value = TagSettingsAlertConstants.ParticulateMatter.lowerBound
        pMatter4UpperBound.value = TagSettingsAlertConstants.ParticulateMatter.upperBound
        pMatter4AlertDescription.value = nil

        isPMatter10AlertOn.value = false
        pMatter10LowerBound.value = TagSettingsAlertConstants.ParticulateMatter.lowerBound
        pMatter10UpperBound.value = TagSettingsAlertConstants.ParticulateMatter.upperBound
        pMatter10AlertDescription.value = nil

        isVOCAlertOn.value = false
        vocLowerBound.value = TagSettingsAlertConstants.VOC.lowerBound
        vocUpperBound.value = TagSettingsAlertConstants.VOC.upperBound
        vocAlertDescription.value = nil

        isNOXAlertOn.value = false
        noxLowerBound.value = TagSettingsAlertConstants.NOX.lowerBound
        noxUpperBound.value = TagSettingsAlertConstants.NOX.upperBound
        noxAlertDescription.value = nil

        isSoundAlertOn.value = false
        soundLowerBound.value = TagSettingsAlertConstants.Sound.lowerBound
        soundUpperBound.value = TagSettingsAlertConstants.Sound.upperBound
        soundAlertDescription.value = nil

        isLuminosityAlertOn.value = false
        luminosityLowerBound.value = TagSettingsAlertConstants.Luminosity.lowerBound
        luminosityUpperBound.value = TagSettingsAlertConstants.Luminosity.upperBound
        luminosityAlertDescription.value = nil

        latestMeasurement.value = nil

        pm1.value = nil
        pm2_5.value = nil
        pm4.value = nil
        pm10.value = nil
        co2.value = nil
        voc.value = nil
        nox.value = nil
        luminance.value = nil
        dbaAvg.value = nil
        dbaPeak.value = nil
    }
}
// swiftlint:enable type_body_length
