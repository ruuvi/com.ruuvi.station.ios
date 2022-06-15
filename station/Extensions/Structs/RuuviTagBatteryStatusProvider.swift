import Foundation
import RuuviOntology

struct RuuviTagBatteryStatusProvider {
    func batteryNeedsReplacement(temperature: Temperature?,
                                 voltage: Voltage?) -> Bool {
        if let temperature = temperature?.value,
            let voltage = voltage?.value {
            if (temperature < -20 && voltage < 2) ||
                (temperature < 0 && voltage < 2.3) ||
                (temperature >= 0 && voltage < 2.5) {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
}
