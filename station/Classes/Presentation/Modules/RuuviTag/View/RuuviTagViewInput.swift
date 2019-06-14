import Foundation

protocol RuuviTagViewInput: ViewInput {
    var name: String? { get set }
    var uuid: String? { get set }
    var temperature: Double? { get set }
    var temperatureUnit: TemperatureUnit? { get set }
    var humidity: Double? { get set }
    var pressure: Double? { get set }
    var rssi: Int? { get set }
    var updated: Date? { get set }
}
