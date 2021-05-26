import Foundation
import RuuviOntology

extension WebTagRealm: VirtualTagSensor {
    var id: String {
        return uuid
    }

//    var any: AnyRuuviTagSensor {
//        return AnyRuuviTagSensor(object: RuuviTagSensorStruct(version: version,
//                                                              luid: uuid,
//                                                              mac: mac,
//                                                              isConnectable: isConnectable,
//                                                              name: name))
//    }
}
