import Foundation

extension RuuviTagRealm: RuuviTagSensor {
    var luid: LocalIdentifier? {
        return uuid.luid
    }

    var any: AnyRuuviTagSensor {
        return AnyRuuviTagSensor(object: RuuviTagSensorStruct(version: version,
                                                              luid: luid,
                                                              mac: mac,
                                                              isConnectable: isConnectable,
                                                              name: name))
    }
}
