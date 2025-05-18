import BTKit
import Humidity
import RuuviLocal
import RuuviOntology
import UIKit
import MobileCoreServices
import Combine

// MARK: - Card type

enum CardType {
    case ruuvi
}

// MARK: - View‑model

final class CardsViewModel: NSObject, ObservableObject {

    // MARK: Immutable identity (for diffable DS)
    private let identity: String
    /// `Identifiable` conformance
    var id: String { identity }

    /// `Hashable` – only the immutable identity participates
    override var hash: Int { identity.hashValue }
    static func == (lhs: CardsViewModel, rhs: CardsViewModel) -> Bool { lhs.identity == rhs.identity }

    // MARK: Dirty flag driving cell refresh
    @Published var dirtyVersion = UUID()
    private func markDirty() { dirtyVersion = UUID() }

    // MARK: - Basic metadata (fields that change UI)

    @Published var type: CardType = .ruuvi

    // Core sensor identifiers (mutable for legacy code, excluded from hash)
    @Published var sensorId: String?            { didSet { markDirty() } }
    @Published var luid: AnyLocalIdentifier?    { didSet { markDirty() } }
    @Published var mac: AnyMACIdentifier?       { didSet { markDirty() } }
    @Published var serviceUUID: String?         { didSet { markDirty() } }

    @Published var name: String = ""            { didSet { markDirty() } }
    @Published var version: Int?                { didSet { markDirty() } }
    @Published var isConnectable: Bool = false  { didSet { markDirty() } }
    @Published var isConnected: Bool = false    { didSet { markDirty() } }
    @Published var isCloud: Bool = false        { didSet { markDirty() } }
    @Published var isOwner: Bool = false
    @Published var canShareTag: Bool = false

    // Data reading source
    @Published var source: RuuviTagSensorRecordSource? { didSet { markDirty() } }

    // Measurements displayed in cells
    @Published var temperature: Temperature? { didSet { markDirty() } }
    @Published var humidity: Humidity?       { didSet { markDirty() } }
    @Published var pressure: Pressure?       { didSet { markDirty() } }
    @Published var pm2_5: Double?            { didSet { markDirty() } }
    @Published var co2: Double?              { didSet { markDirty() } }
    @Published var voc: Double?              { didSet { markDirty() } }
    @Published var nox: Double?              { didSet { markDirty() } }
    @Published var luminance: Double?        { didSet { markDirty() } }
    @Published var dbaAvg: Double?           { didSet { markDirty() } }

    // Battery + background
    @Published var batteryNeedsReplacement: Bool? { didSet { markDirty() } }
    @Published var background: UIImage?          { didSet { markDirty() } }

    // Misc UI flags
    @Published var date: Date? { didSet { markDirty() } }
    @Published var alertState: AlertState? { didSet { markDirty() } }
    @Published var networkSyncStatus: NetworkSyncStatus = .none { didSet { markDirty() } }

    // Keep latest record for detail screens (doesn’t mark dirty)
    @Published var latestMeasurement: RuuviTagSensorRecord?

    // ---- Alerts (kept verbatim, mutate rarely, still observed by cells)
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

    // MARK: Private helpers
    private let batteryStatusProvider = RuuviTagBatteryStatusProvider()

    // MARK: Init
    init(_ ruuviTag: RuuviTagSensor) {
        self.identity = ruuviTag.id
        super.init()

        self.type = .ruuvi
        self.sensorId = ruuviTag.id
        self.luid = ruuviTag.luid?.any
        self.mac  = ruuviTag.macId?.any
        self.serviceUUID = ruuviTag.serviceUUID
        self.name = ruuviTag.name
        self.version = ruuviTag.version
        self.isConnectable = ruuviTag.isConnectable
        self.isCloud = ruuviTag.isCloud
        self.isOwner = ruuviTag.isOwner
        self.canShareTag = (ruuviTag.isOwner && ruuviTag.isClaimed) || ruuviTag.canShare
        self.isConnected = false
        markDirty()
    }

    // MARK: Update with measurement
    func update(_ record: RuuviTagSensorRecord) {
        latestMeasurement = record

        temperature = record.temperature
        humidity    = record.humidity
        pressure    = record.pressure
        pm2_5       = record.pm2_5
        co2         = record.co2
        voc         = record.voc
        nox         = record.nox
        luminance   = record.luminance
        dbaAvg      = record.dbaAvg

        date   = record.date
        source = record.source
        if let macId = record.macId?.any { mac = macId }

        batteryNeedsReplacement = batteryStatusProvider.batteryNeedsReplacement(
            temperature: record.temperature,
            voltage:     record.voltage
        )
    }
}

// MARK: - Drag & drop support

extension CardsViewModel: Reorderable {
    var orderElement: String { identity }
}

extension CardsViewModel: NSItemProviderWriting {
    public static var writableTypeIdentifiersForItemProvider: [String] {
        [kUTTypePlainText as String]
    }

    public func loadData(withTypeIdentifier typeIdentifier: String,
                         forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 100
        completionHandler(identity.data(using: .utf8), nil)
        return progress
    }
}
