import Foundation
import RuuviOntology

extension Humidity {
    func offseted(by offset: Double?, temperature: Temperature?) -> Humidity? {
        guard let offset,
              let temperature
        else {
            return nil
        }
        let relativeHumidity = converted(to: .relative(temperature: temperature)).value
        return Humidity(relative: relativeHumidity + offset, temperature: temperature)
    }
}
