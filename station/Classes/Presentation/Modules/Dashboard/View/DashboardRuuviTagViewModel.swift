import UIKit

struct DashboardRuuviTagViewModel {
    var uuid: String
    var name: String
    var celsius: Double
    var humidity: Double
    var pressure: Double
    var rssi: Int
    var version: Int
    var voltage: Double?
    var background: UIImage?
    var mac: String?
    var humidityOffset: Double = 0
    var humidityOffsetDate: Date?
    
    var fahrenheit: Double {
        return (celsius * 9.0/5.0) + 32.0
    }
}

extension DashboardRuuviTagViewModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}

extension DashboardRuuviTagViewModel: Equatable {
    public static func ==(lhs: DashboardRuuviTagViewModel, rhs: DashboardRuuviTagViewModel) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
