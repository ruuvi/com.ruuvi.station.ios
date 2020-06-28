import Foundation
import Future
import BTKit
import Humidity

protocol RuuviNetworkKaltiot: RuuviNetwork {
    func validateApiKey(apiKey: String) -> Future<Void, RUError>
    func beacons(page: Int) -> Future<KaltiotBeacons, RUError>
    func history(ids: [String], from: TimeInterval?, to: TimeInterval?) -> Future<[KaltiotBeaconLogs], RUError>
}

extension RuuviNetworkKaltiot {
    func load(ruuviTagId: String, mac: String, isConnectable: Bool) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        let operation = history(ids: [mac], from: nil, to: nil)
        operation.on(success: { (records) in
            let decoder = Ruuvi.decoder
            guard let log = records.first else {
                return
            }
            let results: [RuuviTagSensorRecord] = log.history.compactMap { (logItem) -> RuuviTagSensorRecord? in
                // TODO resolve rssi value
                if let device = decoder.decodeNetwork(uuid: ruuviTagId,
                                                      rssi: 0,
                                                      isConnectable: isConnectable,
                                                      payload: logItem.value),
                    let tag = device.ruuvi?.tag {
                    let macId = tag.macId ?? MACIdentifierStruct(value: mac)
                    let record = RuuviTagSensorRecordStruct(ruuviTagId: tag.ruuviTagId,
                                                            date: logItem.date,
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
        }, failure: { (error) in
            promise.fail(error: error)
        }, completion: nil)
        return promise.future
    }

    func getSensor(for beacon: KaltiotBeacon) -> Future<AnyRuuviTagSensor, RUError> {
        let promise = Promise<AnyRuuviTagSensor, RUError>()
        let operation = history(ids: [beacon.id], from: nil, to: nil)
        operation.on(success: { (records) in
            let decoder = Ruuvi.decoder
            guard let log = records.first else {
                return
            }
            let result: [RuuviTag] = log.history.compactMap { (logItem) -> RuuviTag? in
                if let device = decoder.decodeNetwork(uuid: beacon.id,
                                                      rssi: 0,
                                                      isConnectable: true,
                                                      payload: logItem.value),
                    let tag = device.ruuvi?.tag {
                    return (tag)
                } else {
                    return nil
                }
            }
            if let tag = result.first {
                let macId = tag.macId ?? MACIdentifierStruct(value: tag.id)
                let name = "RuuviNetworkKaltiot.Name.prefix".localized()
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
        }, failure: { (error) in
            promise.fail(error: error)
        }, completion: nil)
        return promise.future
    }
}
