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

extension CardsViewModel {

    // Combines all `@Published` properties into a single publisher
    // swiftlint:disable:next function_body_length
    func combinedPublisher() -> AnyPublisher<Void, Never> {
        let publishers: [AnyPublisher<Void, Never>] = [
            $name.map { _ in }.eraseToAnyPublisher(),
            $version.map { _ in }.eraseToAnyPublisher(),
            $isConnectable.map { _ in }.eraseToAnyPublisher(),
            $isConnected.map { _ in }.eraseToAnyPublisher(),
            $isCloud.map { _ in }.eraseToAnyPublisher(),
            $isOwner.map { _ in }.eraseToAnyPublisher(),
            $canShareTag.map { _ in }.eraseToAnyPublisher(),
            $source.map { _ in }.eraseToAnyPublisher(),
            $temperature.map { _ in }.eraseToAnyPublisher(),
            $humidity.map { _ in }.eraseToAnyPublisher(),
            $pressure.map { _ in }.eraseToAnyPublisher(),
            $rssi.map { _ in }.eraseToAnyPublisher(),
            $voltage.map { _ in }.eraseToAnyPublisher(),
            $pm1.map { _ in }.eraseToAnyPublisher(),
            $pm2_5.map { _ in }.eraseToAnyPublisher(),
            $pm4.map { _ in }.eraseToAnyPublisher(),
            $pm10.map { _ in }.eraseToAnyPublisher(),
            $co2.map { _ in }.eraseToAnyPublisher(),
            $voc.map { _ in }.eraseToAnyPublisher(),
            $nox.map { _ in }.eraseToAnyPublisher(),
            $luminance.map { _ in }.eraseToAnyPublisher(),
            $dbaAvg.map { _ in }.eraseToAnyPublisher(),
            $dbaPeak.map { _ in }.eraseToAnyPublisher(),
            $batteryNeedsReplacement.map { _ in }.eraseToAnyPublisher(),
            $background.map { _ in }.eraseToAnyPublisher(),
            $date.map { _ in }.eraseToAnyPublisher(),
            $animateRSSI.map { _ in }.eraseToAnyPublisher(),
            $alertState.map { _ in }.eraseToAnyPublisher(),
            $rhAlertLowerBound.map { _ in }.eraseToAnyPublisher(),
            $rhAlertUpperBound.map { _ in }.eraseToAnyPublisher(),
            $networkSyncStatus.map { _ in }.eraseToAnyPublisher(),
            $movementCounter.map { _ in }.eraseToAnyPublisher(),
            $isChartAvailable.map { _ in }.eraseToAnyPublisher(),
            $isAlertAvailable.map { _ in }.eraseToAnyPublisher(),
            $latestMeasurement.map { _ in }.eraseToAnyPublisher(),
            $isTemperatureAlertOn.map { _ in }.eraseToAnyPublisher(),
            $temperatureAlertState.map { _ in }.eraseToAnyPublisher(),
            $temperatureAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isRelativeHumidityAlertOn.map { _ in }.eraseToAnyPublisher(),
            $relativeHumidityAlertState.map { _ in }.eraseToAnyPublisher(),
            $relativeHumidityAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isPressureAlertOn.map { _ in }.eraseToAnyPublisher(),
            $pressureAlertState.map { _ in }.eraseToAnyPublisher(),
            $pressureAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isSignalAlertOn.map { _ in }.eraseToAnyPublisher(),
            $signalAlertState.map { _ in }.eraseToAnyPublisher(),
            $signalAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isMovementAlertOn.map { _ in }.eraseToAnyPublisher(),
            $movementAlertState.map { _ in }.eraseToAnyPublisher(),
            $movementAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isConnectionAlertOn.map { _ in }.eraseToAnyPublisher(),
            $connectionAlertState.map { _ in }.eraseToAnyPublisher(),
            $connectionAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isCarbonDioxideAlertOn.map { _ in }.eraseToAnyPublisher(),
            $carbonDioxideAlertState.map { _ in }.eraseToAnyPublisher(),
            $carbonDioxideAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isPMatter1AlertOn.map { _ in }.eraseToAnyPublisher(),
            $pMatter1AlertState.map { _ in }.eraseToAnyPublisher(),
            $pMatter1AlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isPMatter2_5AlertOn.map { _ in }.eraseToAnyPublisher(),
            $pMatter2_5AlertState.map { _ in }.eraseToAnyPublisher(),
            $pMatter2_5AlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isPMatter4AlertOn.map { _ in }.eraseToAnyPublisher(),
            $pMatter4AlertState.map { _ in }.eraseToAnyPublisher(),
            $pMatter4AlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isPMatter10AlertOn.map { _ in }.eraseToAnyPublisher(),
            $pMatter10AlertState.map { _ in }.eraseToAnyPublisher(),
            $pMatter10AlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isVOCAlertOn.map { _ in }.eraseToAnyPublisher(),
            $vocAlertState.map { _ in }.eraseToAnyPublisher(),
            $vocAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isNOXAlertOn.map { _ in }.eraseToAnyPublisher(),
            $noxAlertState.map { _ in }.eraseToAnyPublisher(),
            $noxAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isSoundAlertOn.map { _ in }.eraseToAnyPublisher(),
            $soundAlertState.map { _ in }.eraseToAnyPublisher(),
            $soundAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isLuminosityAlertOn.map { _ in }.eraseToAnyPublisher(),
            $luminosityAlertState.map { _ in }.eraseToAnyPublisher(),
            $luminosityAlertMutedTill.map { _ in }.eraseToAnyPublisher(),
            $isCloudConnectionAlertOn.map { _ in }.eraseToAnyPublisher(),
            $cloudConnectionAlertState.map { _ in }.eraseToAnyPublisher(),
        ]

        return Publishers.MergeMany(publishers)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
