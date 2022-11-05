import Foundation
import RuuviOntology

struct RuuviTagBatteryStatusProvider {
    func batteryNeedsReplacement(temperature: Temperature?,
                                 voltage: Voltage?) -> Bool {
        if let temperature = temperature?.value,
            let voltage = voltage?.value {
            if temperature < 0 && temperature >= -20 {
                return voltage < 2.3
            } else if temperature < -20 {
                return voltage < 2
            } else {
                return voltage < 2.5
            }
        } else {
            return false
        }
    }
}
