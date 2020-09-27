import Foundation
import Humidity
import Future

class ExportServiceTrunk: ExportService {
    var ruuviTagTrunk: RuuviTagTrunk!
    var measurementService: MeasurementsService!
    var calibrationService: CalibrationService!

    private var queue = DispatchQueue(label: "com.ruuvi.station.ExportServiceTrunk.queue", qos: .userInitiated)

    private let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()

    func csvLog(for uuid: String) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        let ruuviTag = ruuviTagTrunk.readOne(uuid)
        ruuviTag.on(success: { [weak self] ruuviTag in
            let recordsOperation = self?.ruuviTagTrunk.readAll(uuid)
            recordsOperation?.on(success: { [weak self] records in
                self?.csvLog(for: ruuviTag, with: records).on(success: { url in
                    promise.succeed(value: url)
                }, failure: { error in
                    promise.fail(error: error)
                })
            }, failure: { error in
                promise.fail(error: error)
            })
        }, failure: { error in
            promise.fail(error: error)
        })

        return promise.future
    }
}

// MARK: - Ruuvi Tag
extension ExportServiceTrunk {

    private func getHeaders(_ units: MeasurementsServiceSettigsUnit) -> [String] {
        let tempFormat = "ExportService.Temperature".localized()
        let pressureFormat = "ExportService.Pressure".localized()
        let dewPointFormat = "ExportService.DewPoint".localized()
        return [
            "Date".localized(),
            "ISO8601".localized(),
            String(format: tempFormat, units.temperatureUnit.symbol),
            units.humidityUnit == .dew
                ? String(format: dewPointFormat, units.temperatureUnit.symbol)
                : units.humidityUnit.title,
            String(format: pressureFormat, units.pressureUnit.symbol),
            "ExportService.AccelerationX".localized(),
            "ExportService.AccelerationY".localized(),
            "ExportService.AccelerationZ".localized(),
            "ExportService.Voltage".localized(),
            "ExportService.MovementCounter".localized(),
            "ExportService.MeasurementSequenceNumber".localized(),
            "ExportService.TXPower".localized()
        ]
    }

    // swiftlint:disable:next function_body_length
    private func csvLog(for ruuviTag: RuuviTagSensor, with records: [RuuviTagSensorRecord]) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd-HHmm"
        let date = dateFormatter.string(from: Date())
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let group = DispatchGroup()
        let units = measurementService.units
        let offset: Double
        if let luid = ruuviTag.any.luid {
            offset = calibrationService.humidityOffset(for: luid).0
        } else {
            offset = .zero
        }
        queue.async {
            autoreleasepool {
                group.enter()
                guard let units = units else {
                    group.leave()
                    return
                }
                let fileName = ruuviTag.name + "-" + date + ".csv"
                let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
                let headersString = self.getHeaders(units)
                    .joined(separator: ",")
                    .dropLast()
                var csvText = "\(ruuviTag.name)\n" + headersString + "\n"

                func toString(_ value: Double?, format: String) -> String {
                    guard let v = value else {
                        return "N/A".localized()
                    }
                    return String(format: format, v)
                }

                for log in records {
                    autoreleasepool {
                        let date = dateFormatter.string(from: log.date)
                        let iso = self.iso8601.string(from: log.date)

                        let t = self.measurementService.double(for: log.temperature)
                        let temperature: String = toString(t, format: "%.2f")

                        let h = self.measurementService.double(for: log.humidity,
                                                                  withOffset: offset,
                                                                  temperature: log.temperature,
                                                                  isDecimal: false)
                        let humidity: String = toString(h, format: "%.2f")

                        let p = self.measurementService.double(for: log.pressure)
                        let pressure: String = toString(p, format: "%.2f")

                        let accelerationX: String = toString(log.acceleration?.x.value, format: "%.3f")
                        let accelerationY: String = toString(log.acceleration?.y.value, format: "%.3f")
                        let accelerationZ: String = toString(log.acceleration?.z.value, format: "%.3f")

                        let voltage: String = toString(log.voltage?.converted(to: .volts).value, format: "%.3f")

                        let movementCounter: String
                        if let mc = log.movementCounter {
                            movementCounter = "\(mc)"
                        } else {
                            movementCounter = "N/A".localized()
                        }

                        var measurementSequenceNumber: String
                        if let msn = log.measurementSequenceNumber {
                            measurementSequenceNumber = "\(msn)"
                        } else {
                            measurementSequenceNumber = "N/A".localized()
                        }

                        var txPower: String
                        if let tx = log.txPower {
                            txPower = "\(tx)"
                        } else {
                            txPower = "N/A".localized()
                        }
                        let newLine = "\(date)" + ","
                            + "\(iso)" + ","
                            + "\(temperature)" + ","
                            + "\(humidity)" + ","
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
            }
        }
        return promise.future
    }
}
