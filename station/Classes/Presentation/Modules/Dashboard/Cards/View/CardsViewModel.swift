import UIKit
import BTKit
import Humidity

enum CardType {
    case ruuvi
    case web
}

struct CardsViewModel {
    var type: CardType = .ruuvi
    var uuid: Observable<String?> = Observable<String?>(UUID().uuidString)
    var name: Observable<String?> = Observable<String?>()
    var celsius: Observable<Double?> = Observable<Double?>()
    var fahrenheit: Observable<Double?> = Observable<Double?>()
    var kelvin: Observable<Double?> = Observable<Double?>()
    var relativeHumidity: Observable<Double?> = Observable<Double?>()
    var absoluteHumidity: Observable<Double?> = Observable<Double?>()
    var dewPointCelsius: Observable<Double?> = Observable<Double?>()
    var dewPointFahrenheit: Observable<Double?> = Observable<Double?>()
    var dewPointKelvin: Observable<Double?> = Observable<Double?>()
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
    var location: Observable<Location?> = Observable<Location?>()
    var currentLocation: Observable<Location?> = Observable<Location?>()
    var animateRSSI: Observable<Bool?> = Observable<Bool?>()
    var isConnectable: Observable<Bool?> = Observable<Bool?>()
    var provider: WeatherProvider?
    var isConnected: Observable<Bool?> = Observable<Bool?>()
    var alertState: Observable<AlertState?> = Observable<AlertState?>()

    init(_ webTag: WebTagRealm) {
        type = .web
        uuid.value = webTag.uuid
        name.value = webTag.name
        celsius.value = webTag.data.last?.celsius.value
        fahrenheit.value = webTag.data.last?.fahrenheit
        kelvin.value = webTag.data.last?.kelvin
        relativeHumidity.value = webTag.data.last?.humidity.value
        isConnectable.value = false
        isConnected.value = false

        if let c = webTag.data.last?.celsius.value, let rh = webTag.data.last?.humidity.value {
            let h = Humidity(c: c, rh: rh / 100.0)
            absoluteHumidity.value = h.ah
            dewPointCelsius.value = h.Td
            dewPointFahrenheit.value = h.TdF
            dewPointKelvin.value = h.TdK
        } else {
            absoluteHumidity.value = nil
            dewPointCelsius.value = nil
            dewPointFahrenheit.value = nil
            dewPointKelvin.value = nil
        }
        pressure.value = webTag.data.last?.pressure.value
        date.value = webTag.data.last?.date
        location.value = webTag.location?.location
        provider = webTag.provider
    }

    func update(_ data: WebTagDataRealm) {
        celsius.value = data.celsius.value
        fahrenheit.value = data.fahrenheit
        kelvin.value = data.kelvin
        pressure.value = data.pressure.value
        relativeHumidity.value = data.humidity.value
        isConnectable.value = false
        isConnected.value = false

        if let c = data.celsius.value, let rh = data.humidity.value {
            let h = Humidity(c: c, rh: rh / 100.0)
            absoluteHumidity.value = h.ah
            dewPointCelsius.value = h.Td
            dewPointFahrenheit.value = h.TdF
            dewPointKelvin.value = h.TdK
        } else {
            absoluteHumidity.value = nil
            dewPointCelsius.value = nil
            dewPointFahrenheit.value = nil
            dewPointKelvin.value = nil
        }
        currentLocation.value = data.location?.location
        date.value = data.date
    }

    func update(_ wpsData: WPSData, current: Location?) {
        celsius.value = wpsData.celsius
        fahrenheit.value = wpsData.fahrenheit
        kelvin.value = wpsData.kelvin
        pressure.value = wpsData.pressure
        relativeHumidity.value = wpsData.humidity
        isConnectable.value = false

        if let c = wpsData.celsius, let rh = wpsData.humidity {
            let h = Humidity(c: c, rh: rh / 100.0)
            absoluteHumidity.value = h.ah
            dewPointCelsius.value = h.Td
            dewPointFahrenheit.value = h.TdF
            dewPointKelvin.value = h.TdK
        } else {
            absoluteHumidity.value = nil
            dewPointCelsius.value = nil
            dewPointFahrenheit.value = nil
            dewPointKelvin.value = nil
        }
        currentLocation.value = current
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
        isConnectable.value = ruuviTag.isConnectable

        celsius.value = ruuviTag.data.last?.celsius.value
        fahrenheit.value = ruuviTag.data.last?.fahrenheit
        kelvin.value = ruuviTag.data.last?.kelvin
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
            dewPointKelvin.value = h.TdK
        } else {
            absoluteHumidity.value = nil
            dewPointCelsius.value = nil
            dewPointFahrenheit.value = nil
            dewPointKelvin.value = nil
        }
        pressure.value = ruuviTag.data.last?.pressure.value

        voltage.value = ruuviTag.data.last?.voltage.value

        date.value = ruuviTag.data.last?.date
    }

    func update(with ruuviTag: RuuviTag) {
        uuid.value = ruuviTag.uuid
        isConnectable.value = ruuviTag.isConnectable

        celsius.value = ruuviTag.celsius
        fahrenheit.value = ruuviTag.fahrenheit
        kelvin.value = ruuviTag.kelvin
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
                dewPointKelvin.value = h.TdK
            } else {
                let h = Humidity(c: c, rh: rh / 100.0)
                absoluteHumidity.value = h.ah
                dewPointCelsius.value = h.Td
                dewPointFahrenheit.value = h.TdF
                dewPointKelvin.value = h.TdK
            }
        } else {
            absoluteHumidity.value = nil
            dewPointCelsius.value = nil
            dewPointFahrenheit.value = nil
            dewPointKelvin.value = nil
        }
        pressure.value = ruuviTag.pressure

        version.value = ruuviTag.version
        voltage.value = ruuviTag.voltage

        mac.value = ruuviTag.mac
        date.value = Date()
    }

    func update(rssi: Int?, animated: Bool = false) {
        self.animateRSSI.value = animated
        self.rssi.value = rssi
    }
}

extension CardsViewModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid.value)
    }
}

extension CardsViewModel: Equatable {
    public static func == (lhs: CardsViewModel, rhs: CardsViewModel) -> Bool {
        return lhs.uuid.value == rhs.uuid.value
    }
}
