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
    init(_ ruuviTag: RuuviTagRealm, hours: Int, every seconds: Int) {
        type = .ruuvi
        uuid.value = ruuviTag.uuid
        name.value = ruuviTag.name
        isConnectable.value = ruuviTag.isConnectable
        let ho = ruuviTag.humidityOffset
        humidityOffset.value = ho

        var date = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        let data = ruuviTag.data.filter("date > %@", date).sorted(byKeyPath: "date")
        if data.count > 1 {
            var celsiusPoints = [TagChartsPoint]()
            var fahrenheitPoints = [TagChartsPoint]()
            var kelvinPoints = [TagChartsPoint]()
            var relativeHumidityPoints = [TagChartsPoint]()
            var absoluteHumidityPoints = [TagChartsPoint]()
            var dewPointCelsiusPoints = [TagChartsPoint]()
            var dewPointFahrenheitPoints = [TagChartsPoint]()
            var dewPointKelvinPoints = [TagChartsPoint]()
            var pressurePoints = [TagChartsPoint]()
            for index in 0..<data.count {
                let dataPoint = data[index]
                let elapsed = Int(dataPoint.date.timeIntervalSince(date))
                if elapsed > seconds {
                    if let value = dataPoint.celsius.value {
                        let point = TagChartsPoint(date: dataPoint.date, value: value)
                        celsiusPoints.append(point)
                    }
                    if let value = dataPoint.fahrenheit {
                        let point = TagChartsPoint(date: dataPoint.date, value: value)
                        fahrenheitPoints.append(point)
                    }
                    if let value = dataPoint.kelvin {
                        let point = TagChartsPoint(date: dataPoint.date, value: value)
                        kelvinPoints.append(point)
                    }
                    if let rh = dataPoint.humidity.value {
                        var sh = rh + ho
                        if sh > 100.0 {
                            sh = 100.0
                        }
                        let point = TagChartsPoint(date: dataPoint.date, value: sh)
                        relativeHumidityPoints.append(point)
                    }
                    if let c = dataPoint.celsius.value,
                        let rh = dataPoint.humidity.value {
                        var sh = rh + ho
                        if sh > 100.0 {
                            sh = 100.0
                        }
                        let h = Humidity(c: c, rh: sh / 100.0)
                        let point = TagChartsPoint(date: dataPoint.date, value: h.ah)
                        absoluteHumidityPoints.append(point)
                    }
                    if let c = dataPoint.celsius.value,
                        let rh = dataPoint.humidity.value {
                        var sh = rh + ho
                        if sh > 100.0 {
                            sh = 100.0
                        }
                        let h = Humidity(c: c, rh: sh / 100.0)
                        if let hTd = h.Td {
                            let point = TagChartsPoint(date: dataPoint.date, value: hTd)
                            dewPointCelsiusPoints.append(point)
                        }
                    }
                    if let c = dataPoint.celsius.value,
                        let rh = dataPoint.humidity.value {
                        var sh = rh + ho
                        if sh > 100.0 {
                            sh = 100.0
                        }
                        let h = Humidity(c: c, rh: sh / 100.0)
                        if let hTdF = h.TdF {
                            let point = TagChartsPoint(date: dataPoint.date, value: hTdF)
                            dewPointFahrenheitPoints.append(point)
                        }
                    }
                    if let c = dataPoint.celsius.value,
                        let rh = dataPoint.humidity.value {
                        var sh = rh + ho
                        if sh > 100.0 {
                            sh = 100.0
                        }
                        let h = Humidity(c: c, rh: sh / 100.0)
                        if let hTdK = h.TdK {
                            let point = TagChartsPoint(date: dataPoint.date, value: hTdK)
                            dewPointKelvinPoints.append(point)
                        }
                    }
                    if let pressure = dataPoint.pressure.value {
                        let point = TagChartsPoint(date: dataPoint.date, value: pressure)
                        pressurePoints.append(point)
                    }
                    date = dataPoint.date
                }
            }
            celsius.value = celsiusPoints
            fahrenheit.value = fahrenheitPoints
            kelvin.value = kelvinPoints
            relativeHumidity.value = relativeHumidityPoints
            absoluteHumidity.value = absoluteHumidityPoints
            dewPointCelsius.value = dewPointCelsiusPoints
            dewPointFahrenheit.value = dewPointFahrenheitPoints
            dewPointKelvin.value = dewPointKelvinPoints
            pressure.value = pressurePoints
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
                    if let hTd = h.Td {
                        return TagChartsPoint(date: $0.date, value: hTd)
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
                    if let hTdF = h.TdF {
                        return TagChartsPoint(date: $0.date, value: hTdF)
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
                    if let hTdK = h.TdK {
                        return TagChartsPoint(date: $0.date, value: hTdK)
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
