import Foundation

extension RuuviTagRealm: RuuviTagSensor {
    var luid: String? {
        return uuid
    }

    var any: AnyRuuviTagSensor {
        return AnyRuuviTagSensor(object: RuuviTagSensorStruct(version: version,
                                                              luid: uuid,
                                                              mac: mac,
                                                              isConnectable: isConnectable,
                                                              name: name))
    }
}
