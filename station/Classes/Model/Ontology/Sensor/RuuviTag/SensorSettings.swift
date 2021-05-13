import Foundation

protocol SensorSettings {
    var tagId: String { get }
    
    var temperatureOffset: Double? { get }
    var temperatureOffsetDate: Date? { get }
    var humidityOffset: Double? { get }
    var humidityOffsetDate: Date? { get }
    var pressureOffset: Double? { get }
    var pressureOffsetDate: Date? { get }
}

extension SensorSettings {
    var id: String {
        return "\(tagId)-settings"
    }
}

struct SensorSettingsStruct: SensorSettings {
    var tagId: String
    
    var temperatureOffset: Double?
    var temperatureOffsetDate: Date?
    var humidityOffset: Double?
    var humidityOffsetDate: Date?
    var pressureOffset: Double?
    var pressureOffsetDate: Date?
}
