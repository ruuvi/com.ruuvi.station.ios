import UIKit
import BTKit

struct DashboardRuuviTagViewModel {
    var uuid: Observable<String?> = Observable<String?>(UUID().uuidString)
    var name: Observable<String?> = Observable<String?>()
    var celsius: Observable<Double?> = Observable<Double?>()
    var fahrenheit: Observable<Double?> = Observable<Double?>()
    var humidity: Observable<Double?> = Observable<Double?>()
    var pressure: Observable<Double?> = Observable<Double?>()
    var rssi: Observable<Int?> = Observable<Int?>()
    var version: Observable<Int?> = Observable<Int?>()
    var voltage: Observable<Double?> = Observable<Double?>()
    var background: Observable<UIImage?> = Observable<UIImage?>()
    var mac: Observable<String?> = Observable<String?>()
    var humidityOffset: Observable<Double?> = Observable<Double?>(0)
    var humidityOffsetDate: Observable<Date?> = Observable<Date?>()
    var date: Observable<Date?> = Observable<Date?>()
    var temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    
    init(_ ruuviTag: RuuviTagRealm) {
        uuid.value = ruuviTag.uuid
        name.value = ruuviTag.name
        mac.value = ruuviTag.mac
        version.value = ruuviTag.version
        humidityOffset.value = ruuviTag.humidityOffset
        humidityOffsetDate.value = ruuviTag.humidityOffsetDate
        
        celsius.value = ruuviTag.data.last?.celsius
        fahrenheit.value = ruuviTag.data.last?.fahrenheit
        humidity.value = ruuviTag.data.last?.humidity
        pressure.value = ruuviTag.data.last?.pressure
        
        rssi.value = ruuviTag.data.last?.rssi
        voltage.value = ruuviTag.data.last?.voltage.value
        
        date.value = ruuviTag.data.last?.date
    }
    
    func update(with ruuviTag: RuuviTag) {
        uuid.value = ruuviTag.uuid
        
        celsius.value = ruuviTag.celsius
        fahrenheit.value = ruuviTag.fahrenheit
        humidity.value = ruuviTag.humidity
        pressure.value = ruuviTag.pressure
        
        rssi.value = ruuviTag.rssi
        version.value = ruuviTag.version
        voltage.value = ruuviTag.voltage
        
        mac.value = ruuviTag.mac
        date.value = Date()
    }
}

extension DashboardRuuviTagViewModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid.value)
    }
}

extension DashboardRuuviTagViewModel: Equatable {
    public static func ==(lhs: DashboardRuuviTagViewModel, rhs: DashboardRuuviTagViewModel) -> Bool {
        return lhs.uuid.value == rhs.uuid.value
    }
}
