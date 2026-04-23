import Foundation

public extension String {
    /// Returns a firmware version string adjusted for display by trimming trailing "+0" suffixes.
    var ruuviFirmwareDisplayValue: String {
        guard hasSuffix("+0") else {
            return self
        }
        let endIndex = index(endIndex, offsetBy: -2)
        return String(self[..<endIndex])
    }

    /// Returns a canonical display identifier for comparing persisted firmware labels.
    var canonicalFirmwareDisplayIdentifier: String {
        ruuviFirmwareDisplayValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public extension Optional where Wrapped == String {
    /// Returns a display-friendly firmware version or nil if the result is empty.
    var ruuviFirmwareDisplayValue: String? {
        guard let value = self else {
            return nil
        }
        let sanitized = value.ruuviFirmwareDisplayValue
        return sanitized.isEmpty ? nil : sanitized
    }
}
