import Foundation

/// Shared limits for persisted values, prompt eligibility, and the developer settings editor.
public enum RuuviMarketingConsentPromptInterval {
    public static let defaultMinutes = 180 * 24 * 60
    public static let allowedMinutes = 1...Int(Int32.max)

    public static func normalized(_ minutes: Int) -> Int {
        min(allowedMinutes.upperBound, max(allowedMinutes.lowerBound, minutes))
    }
}
