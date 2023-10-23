import Foundation
import Humidity
import Future
import RuuviOntology
import RuuviStorage
import RuuviService
import RuuviLocal

public final class RuuviServiceExportImpl: RuuviServiceExport {
    private let ruuviStorage: RuuviStorage
    private let measurementService: RuuviServiceMeasurement
    private let emptyValueString: String
    private let headersProvider: RuuviServiceExportHeaders
    private let ruuviLocalSettings: RuuviLocalSettings

    public init(
        ruuviStorage: RuuviStorage,
        measurementService: RuuviServiceMeasurement,
        headersProvider: RuuviServiceExportHeaders,
        emptyValueString: String,
        ruuviLocalSettings: RuuviLocalSettings
    ) {
        self.ruuviStorage = ruuviStorage
        self.measurementService = measurementService
        self.headersProvider = headersProvider
        self.emptyValueString = emptyValueString
        self.ruuviLocalSettings = ruuviLocalSettings
    }

    private var queue = DispatchQueue(label: "com.ruuvi.station.RuuviServiceExportImpl.queue", qos: .userInitiated)

    public func csvLog(for uuid: String, settings: SensorSettings?) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let ruuviTag = ruuviStorage.readOne(uuid)
        ruuviTag.on(success: { [weak self] ruuviTag in
            let recordsOperation = self?.ruuviStorage.readAll(uuid, after: networkPuningDate)
            recordsOperation?.on(success: { [weak self] records in
                let offsetedLogs = records.compactMap({ $0.with(sensorSettings: settings)})
                self?.csvLog(for: ruuviTag, with: offsetedLogs).on(success: { url in
                    promise.succeed(value: url)
                }, failure: { error in
                    promise.fail(error: error)
                })
            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })

        return promise.future
    }
}

// MARK: - Ruuvi Tag
extension RuuviServiceExportImpl {
    // swiftlint:disable:next function_body_length
    private func csvLog(
        for ruuviTag: RuuviTagSensor,
        with records: [RuuviTagSensorRecord]
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmm"
        let date = dateFormatter.string(from: Date())
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let group = DispatchGroup()
        let units = measurementService.units

        // Timezone offset
        let timezoneOffset = TimeZone.autoupdatingCurrent.offsetFromUTC()

        queue.async {
            autoreleasepool {
                group.enter()

                let fileName = ruuviTag.name + "_" + date + "_" + timezoneOffset + ".csv"
                let escapedFileName = fileName.replacingOccurrences(of: "/", with: "_")
                let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(escapedFileName)
                let headersString = self.headersProvider.getHeaders(units)
                    .joined(separator: ",")

                var csvText = headersString + "\n"

                func toString(_ value: Double?, format: String) -> String {
                    guard let v = value else {
                        return self.emptyValueString
                    }
                    return String(format: format, v)
                }

                for log in records {
                    autoreleasepool {
                        let date = dateFormatter.string(from: log.date)

                        let t = self.measurementService.double(for: log.temperature)
                        let temperature: String = toString(t, format: "%.2f")

                        let h = self.measurementService.double(for: log.humidity,
                                                               temperature: log.temperature,
                                                               isDecimal: false)
                        let humidity: String = toString(h, format: "%.2f")

                        var pressure: String
                        let p = self.measurementService.double(for: log.pressure)
                        // Gatt sync returns this -0.01 value for missing sensors, e.g. pressure
                        if p == -0.01 {
                            pressure = toString(nil, format: "%.2f")
                        } else {
                            pressure = toString(p, format: "%.2f")
                        }

                        var rssi: String
                        if let rssiValue = log.rssi {
                            rssi = "\(rssiValue)"
                        } else {
                            rssi = self.emptyValueString
                        }

                        let accelerationX: String = toString(log.acceleration?.x.value, format: "%.3f")
                        let accelerationY: String = toString(log.acceleration?.y.value, format: "%.3f")
                        let accelerationZ: String = toString(log.acceleration?.z.value, format: "%.3f")

                        let voltage: String = toString(log.voltage?.converted(to: .volts).value, format: "%.3f")

                        let movementCounter: String
                        if let mc = log.movementCounter {
                            movementCounter = "\(mc)"
                        } else {
                            movementCounter = self.emptyValueString
                        }

                        var measurementSequenceNumber: String
                        if let msn = log.measurementSequenceNumber {
                            measurementSequenceNumber = "\(msn)"
                        } else {
                            measurementSequenceNumber = self.emptyValueString
                        }

                        var txPower: String
                        if let tx = log.txPower {
                            txPower = "\(tx)"
                        } else {
                            txPower = self.emptyValueString
                        }
                        let newLine = "\(date)" + ","
                            + "\(temperature)" + ","
                            + "\(humidity)" + ","
                            + "\(pressure)" + ","
                            + "\(rssi)" + ","
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

extension TimeZone {
    func offsetFromUTC() -> String {
        let localTimeZoneFormatter = DateFormatter()
        localTimeZoneFormatter.timeZone = self
        localTimeZoneFormatter.dateFormat = "Z"
        let offset = localTimeZoneFormatter.string(from: Date())
        return "UTC" + offset
    }
}
