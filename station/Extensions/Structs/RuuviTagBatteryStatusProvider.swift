import Foundation
import RuuviOntology

struct RuuviTagBatteryStatusProvider {
    func batteryNeedsReplacement(
        temperature: Temperature?,
        voltage: Voltage?
    ) -> Bool {
        if let temperature = temperature?.value,
           let voltage = voltage?.value {
            if temperature < 0, temperature >= -20 {
                voltage < 2.3
            } else if temperature < -20 {
                voltage < 2
            } else {
                voltage < 2.5
            }
        } else {
            false
        }
    }
}
