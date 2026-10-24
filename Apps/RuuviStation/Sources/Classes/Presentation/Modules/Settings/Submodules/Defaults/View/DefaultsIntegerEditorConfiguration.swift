import Foundation
import RuuviLocalization

struct DefaultsIntegerEditorConfiguration {
    struct Preset {
        let title: String
        let value: Int
    }

    let range: ClosedRange<Int>
    let message: String
    let presets: [Preset]
    let formatValue: (Int) -> String

    func validatedValue(from text: String?) -> Int? {
        guard let text, let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              range.contains(value) else { return nil }
        return value
    }

    static func formatMinutes(_ minutes: Int) -> String {
        if minutes.isMultiple(of: 24 * 60) {
            let days = minutes / (24 * 60)
            let unit = days == 1 ? RuuviLocalization.Interval.Day.string : RuuviLocalization.Interval.Days.string
            return "\(days) \(unit)"
        }
        return "\(minutes) \(RuuviLocalization.Defaults.Interval.Min.string)"
    }
}
