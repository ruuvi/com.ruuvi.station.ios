import Foundation

extension Humidity {
    func offseted(by offset: Double?, temperature: Temperature?) -> Humidity? {
        guard let offset = offset,
            let temperature = temperature else {
            return nil
        }
        let relativeHumidity = self.converted(to: .relative(temperature: temperature)).value
        return Humidity.init(relative: relativeHumidity + offset, temperature: temperature)
    }
}
