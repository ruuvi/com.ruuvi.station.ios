import UIKit
import BTKit
import Humidity

enum DashboardTagType {
    case ruuvi
    case web
}

struct DashboardTagViewModel {
    var type: DashboardTagType = .ruuvi
    var uuid: Observable<String?> = Observable<String?>(UUID().uuidString)
    var name: Observable<String?> = Observable<String?>()
    var celsius: Observable<Double?> = Observable<Double?>()
    var fahrenheit: Observable<Double?> = Observable<Double?>()
    var relativeHumidity: Observable<Double?> = Observable<Double?>()
    var absoluteHumidity: Observable<Double?> = Observable<Double?>()
    var dewPointCelsius: Observable<Double?> = Observable<Double?>()
    var dewPointFahrenheit: Observable<Double?> = Observable<Double?>()
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
    var humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()
    var provider: WeatherProvider?
    
    init(_ webTag: WebTagRealm) {
        type = .web
        uuid.value = webTag.uuid
        name.value = webTag.provider.displayName
        provider = webTag.provider
    }
    
    func update(_ webTagData: WebTagData) {
        celsius.value = webTagData.celsius
        fahrenheit.value = webTagData.fahrenheit
        pressure.value = webTagData.pressure
        relativeHumidity.value = webTagData.humidity
        date.value = Date()
    }
    
    init(_ ruuviTag: RuuviTagRealm) {
        type = .ruuvi
        uuid.value = ruuviTag.uuid
        name.value = ruuviTag.name
        mac.value = ruuviTag.mac
        version.value = ruuviTag.version
        humidityOffset.value = ruuviTag.humidityOffset
        humidityOffsetDate.value = ruuviTag.humidityOffsetDate
        
        celsius.value = ruuviTag.data.last?.celsius.value
        fahrenheit.value = ruuviTag.data.last?.fahrenheit
        relativeHumidity.value = ruuviTag.data.last?.humidity.value
        if let c = ruuviTag.data.last?.celsius.value, let rh = ruuviTag.data.last?.humidity.value {
            var sh = rh + ruuviTag.humidityOffset
            if sh > 100.0 {
                sh = 100.0
            }
            let h = Humidity(c: c, rh: sh / 100.0)
            absoluteHumidity.value = h.ah
            dewPointCelsius.value = h.Td
            dewPointFahrenheit.value = h.TdF
        } else {
            absoluteHumidity.value = nil
            dewPointCelsius.value = nil
            dewPointFahrenheit.value = nil
        }
        pressure.value = ruuviTag.data.last?.pressure.value
        
        rssi.value = ruuviTag.data.last?.rssi
        voltage.value = ruuviTag.data.last?.voltage.value
        
        date.value = ruuviTag.data.last?.date
    }
    
    func update(with ruuviTag: RuuviTag) {
        uuid.value = ruuviTag.uuid
        
        celsius.value = ruuviTag.celsius
        fahrenheit.value = ruuviTag.fahrenheit
        relativeHumidity.value = ruuviTag.humidity
        if let c = ruuviTag.celsius, let rh = ruuviTag.humidity {
            if let ho = humidityOffset.value {
                var sh = rh + ho
                if sh > 100.0 {
                    sh = 100.0
                }
                let h = Humidity(c: c, rh: sh / 100.0)
                absoluteHumidity.value = h.ah
                dewPointCelsius.value = h.Td
                dewPointFahrenheit.value = h.TdF
            } else {
                let h = Humidity(c: c, rh: rh / 100.0)
                absoluteHumidity.value = h.ah
                dewPointCelsius.value = h.Td
                dewPointFahrenheit.value = h.TdF
            }
        } else {
            absoluteHumidity.value = nil
            dewPointCelsius.value = nil
            dewPointFahrenheit.value = nil
        }
        pressure.value = ruuviTag.pressure
        
        rssi.value = ruuviTag.rssi
        version.value = ruuviTag.version
        voltage.value = ruuviTag.voltage
        
        mac.value = ruuviTag.mac
        date.value = Date()
    }
}

extension DashboardTagViewModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid.value)
    }
}

extension DashboardTagViewModel: Equatable {
    public static func ==(lhs: DashboardTagViewModel, rhs: DashboardTagViewModel) -> Bool {
        return lhs.uuid.value == rhs.uuid.value
    }
}
