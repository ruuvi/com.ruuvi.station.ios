import Foundation

extension RuuviTagRealm: RuuviTagSensor {
    var luid: LocalIdentifier? {
        return uuid.luid
    }

    var macId: MACIdentifier? {
        return mac?.mac
    }

    var any: AnyRuuviTagSensor {
        return AnyRuuviTagSensor(object: RuuviTagSensorStruct(version: version,
                                                              luid: luid,
                                                              macId: macId,
                                                              isConnectable: isConnectable,
                                                              name: name))
    }
    var networkProvider: RuuviNetworkProvider? {
        return nil
    }
}
