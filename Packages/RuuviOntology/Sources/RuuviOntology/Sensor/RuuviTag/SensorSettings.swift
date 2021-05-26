import Foundation

public protocol SensorSettings {
    var ruuviTagId: String { get }
    var temperatureOffset: Double? { get }
    var temperatureOffsetDate: Date? { get }
    var humidityOffset: Double? { get }
    var humidityOffsetDate: Date? { get }
    var pressureOffset: Double? { get }
    var pressureOffsetDate: Date? { get }
}

extension SensorSettings {
    public var id: String {
        return "\(ruuviTagId)-settings"
    }
}

public struct SensorSettingsStruct: SensorSettings {
    public var ruuviTagId: String
    public var temperatureOffset: Double?
    public var temperatureOffsetDate: Date?
    public var humidityOffset: Double?
    public var humidityOffsetDate: Date?
    public var pressureOffset: Double?
    public var pressureOffsetDate: Date?

    public init(
        ruuviTagId: String,
        temperatureOffset: Double?,
        temperatureOffsetDate: Date?,
        humidityOffset: Double?,
        humidityOffsetDate: Date?,
        pressureOffset: Double?,
        pressureOffsetDate: Date?
    ) {
        self.ruuviTagId = ruuviTagId
        self.temperatureOffset = temperatureOffset
        self.temperatureOffsetDate = temperatureOffsetDate
        self.humidityOffset = humidityOffset
        self.humidityOffsetDate = humidityOffsetDate
        self.pressureOffset = pressureOffset
        self.pressureOffsetDate = pressureOffsetDate
    }
}
