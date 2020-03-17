import Foundation
import RealmSwift
import Humidity
import Future

class ExportServiceTemp: ExportService {

    var realmContext: RealmContext!
    var realmQueue = DispatchQueue(label: "com.ruuvi.station.ExportServiceTemp.realm", qos: .userInitiated)
    private let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()

    func csvLog(for uuid: String) -> Future<URL, RUError> {
        if let ruuviTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
            return csvLog(for: ruuviTag)
        } else if let webTag = realmContext.main.object(ofType: WebTagRealm.self, forPrimaryKey: uuid) {
            return csvLog(for: webTag)
        } else {
            let promise = Promise<URL, RUError>()
            promise.fail(error: .unexpected(.failedToFindLogsForTheTag))
            return promise.future
        }
    }
}

// MARK: - Ruuvi Tag
extension ExportServiceTemp {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func csvLog(for ruuviTag: RuuviTagRealm) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd-HHmm"
        let date = dateFormatter.string(from: Date())
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let ruuviTagRef = ThreadSafeReference(to: ruuviTag)
        let group = DispatchGroup()
        realmQueue.async {
            autoreleasepool {
                let realmBg = try! Realm()
                guard let ruuviTag = realmBg.resolve(ruuviTagRef) else {
                    return
                }
                group.enter()
                let fileName = ruuviTag.name + "-" + date + ".csv"
                let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
                let header = "Date,"
                    + "ISO8601,"
                    + "Celsius,"
                    + "Fahrenheit,"
                    + "Kelvin,"
                    + "Relative Humidity (%),"
                    + "Absolute Humidity (g/m³),"
                    + "Dew point (°C),"
                    + "Dew point (°F),"
                    + "Dew point (K),"
                    + "Pressure (hPa),"
                    + "Acceleration X,"
                    + "Acceleration Y,"
                    + "Acceleration Z,"
                    + "Voltage,"
                    + "Movement Counter,"
                    + "Measurement Sequence Number,"
                    + "TX Power\n"
                var csvText = "\(ruuviTag.name)\n" + header.localized()
                let sortedData = ruuviTag.data.sorted(byKeyPath: "date")
                for log in sortedData {
                    let date = dateFormatter.string(from: log.date)
                    let iso = self.iso8601.string(from: log.date)
                    var celsius: String
                    if let c = log.celsius.value {
                        celsius = String(format: "%.2f", c)
                    } else {
                        celsius = "N/A".localized()
                    }
                    var fahrenheit: String
                    if let f = log.fahrenheit {
                        fahrenheit = String(format: "%.2f", f)
                    } else {
                        fahrenheit = "N/A".localized()
                    }
                    var kelvin: String
                    if let k = log.kelvin {
                        kelvin = String(format: "%.2f", k)
                    } else {
                        kelvin = "N/A".localized()
                    }
                    var relativeHumidity: String
                    if let rh = log.humidity.value {
                        if rh > 100 {
                            relativeHumidity = "100"
                        } else {
                            relativeHumidity = String(format: "%.2f", rh)
                        }
                    } else {
                        relativeHumidity = "N/A".localized()
                    }
                    var absoluteHumidity: String
                    var dewPointCelsius: String
                    var dewPointFahrenheit: String
                    var dewPointKelvin: String
                    if let c = log.celsius.value, let rh = log.humidity.value {
                        var sh = rh + ruuviTag.humidityOffset
                        if sh > 100.0 {
                            sh = 100.0
                        }
                        let h = Humidity(c: c, rh: sh / 100.0)
                        absoluteHumidity = String(format: "%.2f", h.ah)
                        if let hTd = h.Td {
                            dewPointCelsius = String(format: "%.2f", hTd)
                        } else {
                            dewPointCelsius = "N/A".localized()
                        }
                        if let hTdF = h.TdF {
                            dewPointFahrenheit = String(format: "%.2f", hTdF)
                        } else {
                            dewPointFahrenheit = "N/A".localized()
                        }
                        if let hTdK = h.TdK {
                            dewPointKelvin = String(format: "%.2f", hTdK)
                        } else {
                            dewPointKelvin = "N/A".localized()
                        }
                    } else {
                        absoluteHumidity = "N/A".localized()
                        dewPointCelsius = "N/A".localized()
                        dewPointFahrenheit = "N/A".localized()
                        dewPointKelvin = "N/A".localized()
                    }
                    var pressure: String
                    if let p = log.pressure.value {
                        pressure = String(format: "%.2f", p)
                    } else {
                        pressure = "N/A".localized()
                    }
                    var accelerationX: String
                    if let aX = log.accelerationX.value {
                        accelerationX = String(format: "%.3f", aX)
                    } else {
                        accelerationX = "N/A".localized()
                    }
                    var accelerationY: String
                    if let aY = log.accelerationY.value {
                        accelerationY = String(format: "%.3f", aY)
                    } else {
                        accelerationY = "N/A".localized()
                    }
                    var accelerationZ: String
                    if let aZ = log.accelerationZ.value {
                        accelerationZ = String(format: "%.3f", aZ)
                    } else {
                        accelerationZ = "N/A".localized()
                    }
                    let voltage: String
                    if let v = log.voltage.value {
                        voltage = String(format: "%.3f", v)
                    } else {
                        voltage = "N/A".localized()
                    }
                    let movementCounter: String
                    if let mc = log.movementCounter.value {
                        movementCounter = "\(mc)"
                    } else {
                        movementCounter = "N/A".localized()
                    }
                    var measurementSequenceNumber: String
                    if let msn = log.measurementSequenceNumber.value {
                        measurementSequenceNumber = "\(msn)"
                    } else {
                        measurementSequenceNumber = "N/A".localized()
                    }
                    var txPower: String
                    if let tx = log.txPower.value {
                        txPower = "\(tx)"
                    } else {
                        txPower = "N/A".localized()
                    }
                    let newLine = "\(date)" + ","
                        + "\(iso)" + ","
                        + "\(celsius)" + ","
                        + "\(fahrenheit)" + ","
                        + "\(kelvin)" + ","
                        + "\(relativeHumidity)" + ","
                        + "\(absoluteHumidity)" + ","
                        + "\(dewPointCelsius)" + ","
                        + "\(dewPointFahrenheit)" + ","
                        + "\(dewPointKelvin)" + ","
                        + "\(pressure)" + ","
                        + "\(accelerationX)" + ","
                        + "\(accelerationY)" + ","
                        + "\(accelerationZ)" + ","
                        + "\(voltage)" + ","
                        + "\(movementCounter)" + ","
                        + "\(measurementSequenceNumber)" + ","
                        + "\(txPower)\n"
                    csvText.append(contentsOf: newLine)
                }
                group.leave()
                group.notify(queue: .main) {
                    do {
                        try csvText.write(to: path, atomically: true, encoding: .utf8)
                        promise.succeed(value: path)
                    } catch {
                        promise.fail(error: .writeToDisk(error))
                    }
                }
                realmBg.refresh()
                realmBg.invalidate()
            }
        }
        return promise.future
    }
}

// MARK: - Web Tag
extension ExportServiceTemp {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func csvLog(for webTag: WebTagRealm) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd-HHmm"
        let date = dateFormatter.string(from: Date())
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let webTagRef = ThreadSafeReference(to: webTag)
        let group = DispatchGroup()
        realmQueue.async {
            autoreleasepool {
                let realmBg = try! Realm()
                guard let webTag = realmBg.resolve(webTagRef) else {
                    return
                }
                group.enter()
                let fileName = webTag.name + "-" + date + ".csv"
                let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
                let header = "Date,"
                    + "ISO8601,"
                    + "Celsius,"
                    + "Fahrenheit,"
                    + "Kelvin,"
                    + "Relative Humidity (%),"
                    + "Absolute Humidity (g/m³),"
                    + "Dew point (°C),"
                    + "Dew point (°F),"
                    + "Dew point (K),"
                    + "Pressure (hPa),"
                    + "Location\n"
                var csvText = "\(webTag.name)\n" + header.localized()

                let sortedData = webTag.data.sorted(byKeyPath: "date")
                for log in sortedData {
                    let date = dateFormatter.string(from: log.date)
                    let iso = self.iso8601.string(from: log.date)
                    var celsius: String
                    if let c = log.celsius.value {
                        celsius = String(format: "%.2f", c)
                    } else {
                        celsius = "N/A".localized()
                    }
                    var fahrenheit: String
                    if let f = log.fahrenheit {
                        fahrenheit = String(format: "%.2f", f)
                    } else {
                        fahrenheit = "N/A".localized()
                    }
                    var kelvin: String
                    if let k = log.kelvin {
                        kelvin = String(format: "%.2f", k)
                    } else {
                        kelvin = "N/A".localized()
                    }
                    var relativeHumidity: String
                    if let rh = log.humidity.value {
                        if rh > 100 {
                            relativeHumidity = "100"
                        } else {
                            relativeHumidity = String(format: "%.2f", rh)
                        }
                    } else {
                        relativeHumidity = "N/A".localized()
                    }
                    var absoluteHumidity: String
                    var dewPointCelsius: String
                    var dewPointFahrenheit: String
                    var dewPointKelvin: String
                    if let c = log.celsius.value, var rh = log.humidity.value {
                        if rh > 100.0 {
                            rh = 100.0
                        }
                        let h = Humidity(c: c, rh: rh / 100.0)
                        absoluteHumidity = String(format: "%.2f", h.ah)
                        if let hTd = h.Td {
                            dewPointCelsius = String(format: "%.2f", hTd)
                        } else {
                            dewPointCelsius = "N/A".localized()
                        }
                        if let hTdF = h.TdF {
                            dewPointFahrenheit = String(format: "%.2f", hTdF)
                        } else {
                            dewPointFahrenheit = "N/A".localized()
                        }
                        if let hTdK = h.TdK {
                            dewPointKelvin = String(format: "%.2f", hTdK)
                        } else {
                            dewPointKelvin = "N/A".localized()
                        }
                    } else {
                        absoluteHumidity = "N/A".localized()
                        dewPointCelsius = "N/A".localized()
                        dewPointFahrenheit = "N/A".localized()
                        dewPointKelvin = "N/A".localized()
                    }

                    var pressure: String
                    if let p = log.pressure.value {
                        pressure = String(format: "%.2f", p)
                    } else {
                        pressure = "N/A".localized()
                    }
                    var location: String
                    if let c = log.location?.city ?? log.location?.country {
                        location = c
                    } else {
                        location = "N/A".localized()
                    }
                    let newLine = "\(date)" + ","
                        + "\(iso)" + ","
                        + "\(celsius)" + ","
                        + "\(fahrenheit)" + ","
                        + "\(kelvin)" + ","
                        + "\(relativeHumidity)" + ","
                        + "\(absoluteHumidity)" + ","
                        + "\(dewPointCelsius)" + ","
                        + "\(dewPointFahrenheit)" + ","
                        + "\(dewPointKelvin)" + ","
                        + "\(pressure)" + ","
                        + "\(location)\n"
                    csvText.append(contentsOf: newLine)
                }
                group.leave()
                group.notify(queue: .main) {
                    do {
                        try csvText.write(to: path, atomically: true, encoding: .utf8)
                        promise.succeed(value: path)
                    } catch {
                        promise.fail(error: .writeToDisk(error))
                    }
                }
                realmBg.refresh()
                realmBg.invalidate()
            }
        }
        return promise.future
    }
}
