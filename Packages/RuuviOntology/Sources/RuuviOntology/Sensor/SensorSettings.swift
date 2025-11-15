import Foundation

public protocol SensorSettings {
    var id: String { get }
    var luid: LocalIdentifier? { get }
    var macId: MACIdentifier? { get }
    var temperatureOffset: Double? { get }
    var humidityOffset: Double? { get }
    var pressureOffset: Double? { get }
    var displayOrder: [String]? { get }
    var defaultDisplayOrder: Bool? { get }
}

public extension SensorSettings {
    var id: String {
        if let macId {
            "\(macId.value)-settings"
        } else if let luid {
            "\(luid.value)-settings"
        } else {
            fatalError()
        }
    }

    func with(macId: MACIdentifier) -> SensorSettings {
        SensorSettingsStruct(
            luid: luid,
            macId: macId,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset,
            displayOrder: displayOrder,
            defaultDisplayOrder: defaultDisplayOrder
        )
    }
}

public enum OffsetCorrectionType: Int {
    case temperature = 0 // in degrees
    case humidity = 1 // in fraction of one
    case pressure = 2 // in hPa
}

public struct SensorSettingsStruct: SensorSettings {
    public var luid: LocalIdentifier?
    public var macId: MACIdentifier?
    public var temperatureOffset: Double?
    public var humidityOffset: Double?
    public var pressureOffset: Double?
    public var displayOrder: [String]?
    public var defaultDisplayOrder: Bool?

    public init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        displayOrder: [String]? = nil,
        defaultDisplayOrder: Bool? = nil
    ) {
        self.luid = luid
        self.macId = macId
        self.temperatureOffset = temperatureOffset
        self.humidityOffset = humidityOffset
        self.pressureOffset = pressureOffset
        self.displayOrder = displayOrder
        self.defaultDisplayOrder = defaultDisplayOrder
    }
}
