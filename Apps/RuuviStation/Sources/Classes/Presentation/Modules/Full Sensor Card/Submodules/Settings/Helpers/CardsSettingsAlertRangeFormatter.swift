import UIKit
import RuuviLocalization

enum CardsSettingsAlertRangeFormatter {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static let numberRegex = try? NSRegularExpression(pattern: "\\d+([.,]\\d+)?")
    private static let baseFont = UIFont.ruuviSubheadline()
    private static let boldFont = UIFont.mulish(.bold, size: 14)

    private static func numberString(from value: Double) -> String {
        let number = NSNumber(value: value)
        return numberFormatter.string(from: number) ?? "\(value)"
    }

    static func sliderLimitTitle(
        lower: Double,
        upper: Double
    ) -> CardsSettingsAlertActionRowTitle {
        let lowerText = numberString(from: lower)
        let upperText = numberString(from: upper)
        if let attributed = attributedString(
            lowerText: lowerText, upperText: upperText
        ) {
            return .attributed(attributed)
        } else {
            let fallback = RuuviLocalization.TagSettings.Alerts.description(
                lowerText, upperText
            )
            return .plain(fallback)
        }
    }

    private static func attributedString(
        lowerText: String,
        upperText: String
    ) -> AttributedString? {
        let message = RuuviLocalization.TagSettings.Alerts.description(lowerText, upperText)
        let attributed = NSMutableAttributedString(string: message)
        let fullRange = NSRange(location: 0, length: (message as NSString).length)
        attributed.addAttribute(.font, value: baseFont, range: fullRange)
        guard let numberRegex else {
            return AttributedString(attributed)
        }
        let matches = numberRegex.matches(in: message, options: [], range: fullRange)
        matches.forEach { match in
            attributed.addAttribute(.font, value: boldFont, range: match.range)
        }
        return AttributedString(attributed)
    }
}
