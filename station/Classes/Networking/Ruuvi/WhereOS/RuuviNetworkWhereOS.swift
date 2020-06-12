import Foundation
import Future
import BTKit

protocol RuuviNetworkWhereOS: RuuviNetwork {
    func load(mac: String) -> Future<[WhereOSData], RUError>
}

extension RuuviNetworkWhereOS {
    func load(ruuviTagId: String, mac: String, isConnectable: Bool) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        let operation: Future<[WhereOSData], RUError> = load(mac: mac)
        operation.on(success: { records in
            let decoder = Ruuvi.decoder
            let results = records.compactMap { record -> RuuviTagSensorRecord? in
                if let device = decoder.decodeNetwork(uuid: ruuviTagId,
                                                      rssi: record.rssi,
                                                      isConnectable: isConnectable,
                                                      payload: record.data),
                    let tag = device.ruuvi?.tag {
                    let macId = tag.macId ?? MACIdentifierStruct(value: mac)
                    let record = RuuviTagSensorRecordStruct(ruuviTagId: tag.ruuviTagId,
                                                            date: record.time,
                                                            macId: macId,
                                                            rssi: tag.rssi,
                                                            temperature: tag.temperature,
                                                            humidity: tag.humidity,
                                                            pressure: tag.pressure,
                                                            acceleration: tag.acceleration,
                                                            voltage: tag.voltage,
                                                            movementCounter: tag.movementCounter,
                                                            measurementSequenceNumber: tag.measurementSequenceNumber,
                                                            txPower: tag.txPower)
                    return record
                } else {
                    return nil
                }
            }
            promise.succeed(value: results)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    func getSensor(mac: String) -> Future<AnyRuuviTagSensor, RUError> {
        let promise = Promise<AnyRuuviTagSensor, RUError>()
        let operation: Future<[WhereOSData], RUError> = load(mac: mac)
        operation.on(success: { records in
            let decoder = Ruuvi.decoder
            if let record = records.first,
                let device = decoder.decodeNetwork(uuid: mac,
                                                  rssi: record.rssi,
                                                  isConnectable: true,
                                                  payload: record.data),
                let tag = device.ruuvi?.tag {
                let macId = tag.macId ?? MACIdentifierStruct(value: tag.id)
                let name = "RuuviNetworkWhereOS.Name.prefix".localized()
                    + " " + macId.mac.replacingOccurrences(of: ":", with: "").suffix(4)
                let sensorStuct = RuuviTagSensorStruct(version: tag.version,
                                                       luid: nil,
                                                       macId: macId,
                                                       isConnectable: tag.isConnectable,
                                                       name: name)
                let anyStruct = AnyRuuviTagSensor(object: sensorStuct)
                promise.succeed(value: anyStruct)
            } else {
                promise.fail(error: RUError.ruuviNetwork(.noStoredData))
            }
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }
}
