import Foundation

extension UserDefaults {
    func optionalDouble(forKey defaultName: String) -> Double? {
        let defaults = self
        if let value = defaults.value(forKey: defaultName) {
            return value as? Double
        }
        return nil
    }

    func optionalInt(forKey defaultName: String) -> Int? {
        let defaults = self
        if let value = defaults.value(forKey: defaultName) {
            return value as? Int
        }
        return nil
    }

    func optionalBool(forKey defaultName: String) -> Bool? {
        let defaults = self
        if let value = defaults.value(forKey: defaultName) {
            return value as? Bool
        }
        return nil
    }
}
