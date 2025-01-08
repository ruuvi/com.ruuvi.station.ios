import BTKit
import Humidity
import RuuviLocal
import RuuviOntology
import UIKit
import MobileCoreServices
import Combine

enum CardType {
    case ruuvi
}

final class CardsViewModel: NSObject, ObservableObject {
    // MARK: - Basic

    @Published var type: CardType = .ruuvi

    // Core sensor identifiers
    @Published var id: String?
    @Published var luid: AnyLocalIdentifier?
    @Published var mac: AnyMACIdentifier?
    @Published var serviceUUID: String?

    // Basic metadata
    @Published var name: String = ""
    @Published var version: Int?
    @Published var isConnectable: Bool = false
    @Published var isConnected: Bool = false
    @Published var isCloud: Bool = false
    @Published var isOwner: Bool = false
    @Published var canShareTag: Bool = false

    // Data reading source
    @Published var source: RuuviTagSensorRecordSource?

    // Measurement fields
    @Published var temperature: Temperature?
    @Published var humidity: Humidity?
    @Published var pressure: Pressure?
    @Published var rssi: Int?
    @Published var voltage: Voltage?
    @Published var pm1: Double?
    @Published var pm2_5: Double?
    @Published var pm4: Double?
    @Published var pm10: Double?
    @Published var co2: Double?
    @Published var voc: Double?
    @Published var nox: Double?
    @Published var luminance: Double?
    @Published var dbaAvg: Double?
    @Published var dbaPeak: Double?

    // Battery
    @Published var batteryNeedsReplacement: Bool?

    // Background
    @Published var background: UIImage?

    // Date & location
    @Published var date: Date?

    // Others
    @Published var animateRSSI: Bool?
    @Published var alertState: AlertState?
    @Published var rhAlertLowerBound: Double?
    @Published var rhAlertUpperBound: Double?
    @Published var networkSyncStatus: NetworkSyncStatus = .none
    @Published var movementCounter: Int?
    @Published var isChartAvailable: Bool?
    @Published var isAlertAvailable: Bool?

    // Latest measurement record
    @Published var latestMeasurement: RuuviTagSensorRecord?

    // MARK: - Alerts

    @Published var isTemperatureAlertOn: Bool?
    @Published var temperatureAlertState: AlertState?
    @Published var temperatureAlertMutedTill: Date?

    @Published var isRelativeHumidityAlertOn: Bool?
    @Published var relativeHumidityAlertState: AlertState?
    @Published var relativeHumidityAlertMutedTill: Date?

    @Published var isPressureAlertOn: Bool?
    @Published var pressureAlertState: AlertState?
    @Published var pressureAlertMutedTill: Date?

    @Published var isSignalAlertOn: Bool?
    @Published var signalAlertState: AlertState?
    @Published var signalAlertMutedTill: Date?

    @Published var isMovementAlertOn: Bool?
    @Published var movementAlertState: AlertState?
    @Published var movementAlertMutedTill: Date?

    @Published var isConnectionAlertOn: Bool?
    @Published var connectionAlertState: AlertState?
    @Published var connectionAlertMutedTill: Date?

    @Published var isCarbonDioxideAlertOn: Bool?
    @Published var carbonDioxideAlertState: AlertState?
    @Published var carbonDioxideAlertMutedTill: Date?

    @Published var isPMatter1AlertOn: Bool?
    @Published var pMatter1AlertState: AlertState?
    @Published var pMatter1AlertMutedTill: Date?

    @Published var isPMatter2_5AlertOn: Bool?
    @Published var pMatter2_5AlertState: AlertState?
    @Published var pMatter2_5AlertMutedTill: Date?

    @Published var isPMatter4AlertOn: Bool?
    @Published var pMatter4AlertState: AlertState?
    @Published var pMatter4AlertMutedTill: Date?

    @Published var isPMatter10AlertOn: Bool?
    @Published var pMatter10AlertState: AlertState?
    @Published var pMatter10AlertMutedTill: Date?

    @Published var isVOCAlertOn: Bool?
    @Published var vocAlertState: AlertState?
    @Published var vocAlertMutedTill: Date?

    @Published var isNOXAlertOn: Bool?
    @Published var noxAlertState: AlertState?
    @Published var noxAlertMutedTill: Date?

    @Published var isSoundAlertOn: Bool?
    @Published var soundAlertState: AlertState?
    @Published var soundAlertMutedTill: Date?

    @Published var isLuminosityAlertOn: Bool?
    @Published var luminosityAlertState: AlertState?
    @Published var luminosityAlertMutedTill: Date?

    @Published var isCloudConnectionAlertOn: Bool?
    @Published var cloudConnectionAlertState: AlertState?

    // MARK: - Private

    private let batteryStatusProvider = RuuviTagBatteryStatusProvider()

    // MARK: - Init

    init(_ ruuviTag: RuuviTagSensor) {
        super.init()
        type = .ruuvi
        id = ruuviTag.id
        luid = ruuviTag.luid?.any
        if let macId = ruuviTag.macId?.any {
            mac = macId
        }
        serviceUUID = ruuviTag.serviceUUID
        name = ruuviTag.name
        version = ruuviTag.version
        isConnectable = ruuviTag.isConnectable
        isChartAvailable = ruuviTag.isConnectable || ruuviTag.isCloud || ruuviTag.serviceUUID != nil
        isAlertAvailable = ruuviTag.isCloud || isConnected || ruuviTag.serviceUUID != nil
        isCloud = ruuviTag.isCloud
        isOwner = ruuviTag.isOwner
        canShareTag = (ruuviTag.isOwner && ruuviTag.isClaimed) || ruuviTag.canShare
    }

    // MARK: - Update Methods

    func update(_ record: RuuviTagSensorRecord) {
        latestMeasurement = record
        temperature = record.temperature
        humidity = record.humidity
        pressure = record.pressure

        if let macId = record.macId?.any {
            mac = macId
        }

        date = record.date
        rssi = record.rssi
        movementCounter = record.movementCounter
        pm1 = record.pm1
        pm2_5 = record.pm2_5
        pm4 = record.pm4
        pm10 = record.pm10
        co2 = record.co2
        voc = record.voc
        nox = record.nox
        luminance = record.luminance
        dbaAvg = record.dbaAvg
        dbaPeak = record.dbaPeak
        source = record.source

        batteryNeedsReplacement = batteryStatusProvider.batteryNeedsReplacement(
            temperature: record.temperature,
            voltage: record.voltage
        )

        // isAlertAvailable might change if data source changed
        isAlertAvailable = isCloud || isConnected || serviceUUID != nil
    }

    func update(with ruuviTag: RuuviTag) {
        // If connectable changes
        if !ruuviTag.isConnected,
            isConnectable != ruuviTag.isConnectable,
            ruuviTag.isConnectable {
            isConnectable = ruuviTag.isConnectable
            if let isChart = isChartAvailable, !isChart, ruuviTag.isConnectable {
                isChartAvailable = true
            }
        } else {
            if let isChart = isChartAvailable, !isChart, ruuviTag.serviceUUID != nil {
                isChartAvailable = true
            }
        }

        isAlertAvailable = isCloud || ruuviTag.isConnected || ruuviTag.serviceUUID != nil
        temperature = ruuviTag.temperature
        humidity = ruuviTag.humidity
        pressure = ruuviTag.pressure
        version = ruuviTag.version
        voltage = ruuviTag.voltage

        if let macId = ruuviTag.mac?.mac.any {
            mac = macId
        }

        serviceUUID = ruuviTag.serviceUUID
        date = Date()
        movementCounter = ruuviTag.movementCounter
        pm1 = ruuviTag.pm1
        pm2_5 = ruuviTag.pm2_5
        pm4 = ruuviTag.pm4
        pm10 = ruuviTag.pm10
        co2 = ruuviTag.co2
        voc = ruuviTag.voc
        nox = ruuviTag.nox
        luminance = ruuviTag.luminance
        dbaAvg = ruuviTag.dbaAvg
        dbaPeak = ruuviTag.dbaPeak
        source = ruuviTag.source
    }
}

// MARK: - Reorderable

extension CardsViewModel: Reorderable {
    var orderElement: String {
        id ?? UUID().uuidString
    }
}

// MARK: - NSItemProviderWriting for Drag & Drop

extension CardsViewModel: NSItemProviderWriting {
    public static var writableTypeIdentifiersForItemProvider: [String] {
        return [kUTTypePlainText as String]
    }

    public func loadData(
        withTypeIdentifier typeIdentifier: String,
        forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void
    ) -> Progress? {
        return Progress()
    }
}
