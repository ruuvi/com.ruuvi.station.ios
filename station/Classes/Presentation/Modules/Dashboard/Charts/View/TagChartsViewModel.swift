import UIKit
import Humidity

enum TagChartsType {
    case ruuvi
    case web
}

struct TagChartsPoint {
    var date: Date
    var value: Double
}

struct TagChartsViewModel {
    var type: TagChartsType = .ruuvi
    var uuid: Observable<String?> = Observable<String?>(UUID().uuidString)
    var name: Observable<String?> = Observable<String?>()
    var background: Observable<UIImage?> = Observable<UIImage?>()
    var celsius: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    var fahrenheit: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    var kelvin: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    var temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    var humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()
    var relativeHumidity: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    var absoluteHumidity: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    var dewPointCelsius: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    var dewPointFahrenheit: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    var dewPointKelvin: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    var humidityOffset: Observable<Double?> = Observable<Double?>(0)
    var pressure: Observable<[TagChartsPoint]?> = Observable<[TagChartsPoint]?>()
    var isConnectable: Observable<Bool?> = Observable<Bool?>()
    var alertState: Observable<AlertState?> = Observable<AlertState?>()
    var isConnected: Observable<Bool?> = Observable<Bool?>()

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(_ ruuviTag: RuuviTagRealm) {
        type = .ruuvi
        uuid.value = ruuviTag.uuid
        name.value = ruuviTag.name
        isConnectable.value = ruuviTag.isConnectable
        let data = ruuviTag.data.sorted(byKeyPath: "date")
        if data.count > 1 {
            celsius.value = data.compactMap({
                if let value = $0.celsius.value {
                    return TagChartsPoint(date: $0.date, value: value)
                } else {
                    return nil
                }
            })
            fahrenheit.value = data.compactMap({
                if let value = $0.fahrenheit {
                    return TagChartsPoint(date: $0.date, value: value)
                } else {
                    return nil
                }
            })
            kelvin.value = data.compactMap({
                if let value = $0.kelvin {
                    return TagChartsPoint(date: $0.date, value: value)
                } else {
                    return nil
                }
            })

            let ho = ruuviTag.humidityOffset
            humidityOffset.value = ho

            relativeHumidity.value = data.compactMap({
                if let rh = $0.humidity.value {
                    var sh = rh + ho
                    if sh > 100.0 {
                        sh = 100.0
                    }
                    return TagChartsPoint(date: $0.date, value: sh)
                } else {
                    return nil
                }
            })

            absoluteHumidity.value = data.compactMap({
                if let c = $0.celsius.value,
                    let rh = $0.humidity.value {
                    var sh = rh + ho
                    if sh > 100.0 {
                        sh = 100.0
                    }
                    let h = Humidity(c: c, rh: sh / 100.0)
                    return TagChartsPoint(date: $0.date, value: h.ah)
                } else {
                     return nil
                }
            })
            dewPointCelsius.value = data.compactMap({
                if let c = $0.celsius.value,
                    let rh = $0.humidity.value {
                    var sh = rh + ho
                    if sh > 100.0 {
                        sh = 100.0
                    }
                    let h = Humidity(c: c, rh: sh / 100.0)
                    if let Td = h.Td {
                        return TagChartsPoint(date: $0.date, value: Td)
                    } else {
                        return nil
                    }
                } else {
                     return nil
                }
            })
            dewPointFahrenheit.value = data.compactMap({
                if let c = $0.celsius.value,
                    let rh = $0.humidity.value {
                    var sh = rh + ho
                    if sh > 100.0 {
                        sh = 100.0
                    }
                    let h = Humidity(c: c, rh: sh / 100.0)
                    if let TdF = h.TdF {
                        return TagChartsPoint(date: $0.date, value: TdF)
                    } else {
                        return nil
                    }
                } else {
                     return nil
                }
            })
            dewPointKelvin.value = data.compactMap({
                if let c = $0.celsius.value,
                    let rh = $0.humidity.value {
                    var sh = rh + ho
                    if sh > 100.0 {
                        sh = 100.0
                    }
                    let h = Humidity(c: c, rh: sh / 100.0)
                    if let TdK = h.TdK {
                        return TagChartsPoint(date: $0.date, value: TdK)
                    } else {
                        return nil
                    }
                } else {
                     return nil
                }
            })
            pressure.value = data.compactMap({
                if let pressure = $0.pressure.value {
                    return TagChartsPoint(date: $0.date, value: pressure)
                } else {
                    return nil
                }
            })
        } else {
            celsius.value = nil
            fahrenheit.value = nil
            kelvin.value = nil

            let ho = ruuviTag.humidityOffset
            humidityOffset.value = ho

            relativeHumidity.value = nil

            absoluteHumidity.value = nil
            dewPointCelsius.value = nil
            dewPointFahrenheit.value = nil
            dewPointKelvin.value = nil
            pressure.value = nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(_ webTag: WebTagRealm) {
        type = .web
        uuid.value = webTag.uuid
        name.value = webTag.name
        isConnectable.value = false
        let data = webTag.data.sorted(byKeyPath: "date")
        if data.count > 1 {
            celsius.value = data.compactMap({
                if let value = $0.celsius.value {
                    return TagChartsPoint(date: $0.date, value: value)
                } else {
                    return nil
                }
            })
            fahrenheit.value = data.compactMap({
                if let value = $0.fahrenheit {
                    return TagChartsPoint(date: $0.date, value: value)
                } else {
                    return nil
                }
            })
            kelvin.value = data.compactMap({
                if let value = $0.kelvin {
                    return TagChartsPoint(date: $0.date, value: value)
                } else {
                    return nil
                }
            })
            relativeHumidity.value = data.compactMap({
                if let value = $0.humidity.value {
                    return TagChartsPoint(date: $0.date, value: value)
                } else {
                    return nil
                }
            })
            absoluteHumidity.value = data.compactMap({
                if let c = $0.celsius.value,
                    let rh = $0.humidity.value {
                    let h = Humidity(c: c, rh: rh / 100.0)
                    return TagChartsPoint(date: $0.date, value: h.ah)
                } else {
                     return nil
                }
            })
            dewPointCelsius.value = data.compactMap({
                if let c = $0.celsius.value,
                    let rh = $0.humidity.value {
                    let h = Humidity(c: c, rh: rh / 100.0)
                    if let Td = h.Td {
                        return TagChartsPoint(date: $0.date, value: Td)
                    } else {
                        return nil
                    }
                } else {
                     return nil
                }
            })
            dewPointFahrenheit.value = data.compactMap({
                if let c = $0.celsius.value,
                    let rh = $0.humidity.value {
                    let h = Humidity(c: c, rh: rh / 100.0)
                    if let TdF = h.TdF {
                        return TagChartsPoint(date: $0.date, value: TdF)
                    } else {
                        return nil
                    }
                } else {
                     return nil
                }
            })
            dewPointKelvin.value = data.compactMap({
                if let c = $0.celsius.value,
                    let rh = $0.humidity.value {
                    let h = Humidity(c: c, rh: rh / 100.0)
                    if let TdK = h.TdK {
                        return TagChartsPoint(date: $0.date, value: TdK)
                    } else {
                        return nil
                    }
                } else {
                     return nil
                }
            })
            pressure.value = data.compactMap({
                if let pressure = $0.pressure.value {
                    return TagChartsPoint(date: $0.date, value: pressure)
                } else {
                    return nil
                }
            })
        } else {
            celsius.value = nil
            fahrenheit.value = nil
            kelvin.value = nil
            relativeHumidity.value = nil
            absoluteHumidity.value = nil
            dewPointCelsius.value = nil
            dewPointFahrenheit.value = nil
            dewPointKelvin.value = nil
            pressure.value = nil
        }

    }
}
