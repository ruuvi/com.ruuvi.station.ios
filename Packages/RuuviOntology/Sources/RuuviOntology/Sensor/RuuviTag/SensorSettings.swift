import Foundation

public protocol SensorSettings {
    var id: String { get }
    var luid: LocalIdentifier? { get }
    var macId: MACIdentifier? { get }
    var temperatureOffset: Double? { get }
    var temperatureOffsetDate: Date? { get }
    var humidityOffset: Double? { get }
    var humidityOffsetDate: Date? { get }
    var pressureOffset: Double? { get }
    var pressureOffsetDate: Date? { get }
}

extension SensorSettings {
    public var id: String {
        if let macId = macId {
            return "\(macId.value)-settings"
        } else if let luid = luid {
            return "\(luid.value)-settings"
        } else {
            fatalError()
        }
    }
}

public enum OffsetCorrectionType: Int {
    case temperature = 0
    case humidity = 1
    case pressure = 2
}

public struct SensorSettingsStruct: SensorSettings {
    public var luid: LocalIdentifier?
    public var macId: MACIdentifier?
    public var temperatureOffset: Double?
    public var temperatureOffsetDate: Date?
    public var humidityOffset: Double?
    public var humidityOffsetDate: Date?
    public var pressureOffset: Double?
    public var pressureOffsetDate: Date?

    public init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        temperatureOffset: Double?,
        temperatureOffsetDate: Date?,
        humidityOffset: Double?,
        humidityOffsetDate: Date?,
        pressureOffset: Double?,
        pressureOffsetDate: Date?
    ) {
        self.luid = luid
        self.macId = macId
        self.temperatureOffset = temperatureOffset
        self.temperatureOffsetDate = temperatureOffsetDate
        self.humidityOffset = humidityOffset
        self.humidityOffsetDate = humidityOffsetDate
        self.pressureOffset = pressureOffset
        self.pressureOffsetDate = pressureOffsetDate
    }
}
