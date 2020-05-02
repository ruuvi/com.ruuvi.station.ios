import Foundation

extension RuuviTagRealm: RuuviTagSensor {
    var luid: String? {
        return uuid
    }
}
