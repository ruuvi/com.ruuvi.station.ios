import UIKit
import RuuviLocalization

extension NSAttributedString {

    // swiftlint:disable:next function_parameter_count
    static func fromFormattedDescription(
        _ escapedHTML: String,
        titleFont: UIFont,
        paragraphFont: UIFont,
        boldFont: UIFont,
        titleColor: UIColor,
        paragraphColor: UIColor,
        linkColor: UIColor,
        linkFont: UIFont
    ) -> NSAttributedString {
        let unescapedText = unescapeHTML(escapedHTML)

        return processFormattedText(
            unescapedText,
            titleFont: titleFont,
            paragraphFont: paragraphFont,
            boldFont: boldFont,
            titleColor: titleColor,
            paragraphColor: paragraphColor,
            linkColor: linkColor,
            linkFont: linkFont
        )
    }
}

// MARK: - Private Types
private enum MatchType {
    case title
    case bold
    case link
}

// MARK: - Private Processing Methods
private extension NSAttributedString {

    static func unescapeHTML(_ escapedHTML: String) -> String {
        return escapedHTML
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "[", with: "<")
            .replacingOccurrences(of: "]", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    // swiftlint:disable:next function_parameter_count function_body_length
    static func processFormattedText(
        _ text: String,
        titleFont: UIFont,
        paragraphFont: UIFont,
        boldFont: UIFont,
        titleColor: UIColor,
        paragraphColor: UIColor,
        linkColor: UIColor,
        linkFont: UIFont
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remainingText = text

        let titleRegex = createTitleRegex()
        let boldRegex = createBoldRegex()
        let linkRegex = createLinkRegex()

        while !remainingText.isEmpty {
            guard let nextMatch = findNextMatch(
                in: remainingText,
                titleRegex: titleRegex,
                boldRegex: boldRegex,
                linkRegex: linkRegex
            ) else {
                appendRemainingText(remainingText, to: result, font: paragraphFont, color: paragraphColor)
                break
            }

            let (match, matchType) = nextMatch
            let nsString = remainingText as NSString

            appendTextBeforeMatch(
                nsString: nsString,
                match: match,
                to: result,
                font: paragraphFont,
                color: paragraphColor
            )

            switch matchType {
            case .title:
                appendTitleText(
                    match: match,
                    text: remainingText,
                    to: result,
                    font: titleFont,
                    color: titleColor
                )
            case .bold:
                appendBoldText(
                    match: match,
                    text: remainingText,
                    to: result,
                    font: boldFont,
                    color: paragraphColor
                )
            case .link:
                appendLinkText(
                    match: match,
                    text: remainingText,
                    to: result,
                    font: linkFont,
                    color: linkColor
                )
            }

            remainingText = nsString.substring(from: match.range.location + match.range.length)
        }

        return result
    }

    static func createTitleRegex() -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: "<title>(.*?)</title>", options: [])
    }

    static func createBoldRegex() -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: "<b>(.*?)</b>", options: [])
    }

    static func createLinkRegex() -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: "<link url=\\\"?(.*?)\\\"?>(.*?)</link>", options: [])
    }

    static func findNextMatch(
        in text: String,
        titleRegex: NSRegularExpression?,
        boldRegex: NSRegularExpression?,
        linkRegex: NSRegularExpression?
    ) -> (NSTextCheckingResult, MatchType)? {
        let range = NSRange(location: 0, length: text.utf16.count)

        let titleMatch = titleRegex?.firstMatch(in: text, range: range)
        let boldMatch = boldRegex?.firstMatch(in: text, range: range)
        let linkMatch = linkRegex?.firstMatch(in: text, range: range)

        // Find the earliest match
        var earliestMatch: (NSTextCheckingResult, MatchType)?

        if let title = titleMatch {
            earliestMatch = (title, .title)
        }

        if let bold = boldMatch {
            if earliestMatch == nil || bold.range.location < earliestMatch!.0.range.location {
                earliestMatch = (bold, .bold)
            }
        }

        if let link = linkMatch {
            if earliestMatch == nil || link.range.location < earliestMatch!.0.range.location {
                earliestMatch = (link, .link)
            }
        }

        return earliestMatch
    }

    static func appendRemainingText(
        _ text: String,
        to result: NSMutableAttributedString,
        font: UIFont,
        color: UIColor
    ) {
        guard !text.isEmpty else { return }

        let attributedString = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color]
        )
        result.append(attributedString)
    }

    static func appendTextBeforeMatch(
        nsString: NSString,
        match: NSTextCheckingResult,
        to result: NSMutableAttributedString,
        font: UIFont,
        color: UIColor
    ) {
        let beforeTagRange = NSRange(location: 0, length: match.range.location)
        let beforeTagText = nsString.substring(with: beforeTagRange)

        guard !beforeTagText.isEmpty else { return }

        let attributedString = NSAttributedString(
            string: beforeTagText,
            attributes: [.font: font, .foregroundColor: color]
        )
        result.append(attributedString)
    }

    static func appendTitleText(
        match: NSTextCheckingResult,
        text: String,
        to result: NSMutableAttributedString,
        font: UIFont,
        color: UIColor
    ) {
        guard let titleRange = Range(match.range(at: 1), in: text) else { return }

        let titleText = String(text[titleRange])
        let attributedString = NSAttributedString(
            string: titleText,
            attributes: [.font: font, .foregroundColor: color]
        )
        result.append(attributedString)
    }

    static func appendBoldText(
        match: NSTextCheckingResult,
        text: String,
        to result: NSMutableAttributedString,
        font: UIFont,
        color: UIColor
    ) {
        guard let boldRange = Range(match.range(at: 1), in: text) else { return }

        let boldText = String(text[boldRange])
        let attributedString = NSAttributedString(
            string: boldText,
            attributes: [.font: font, .foregroundColor: color]
        )
        result.append(attributedString)
    }

    static func appendLinkText(
        match: NSTextCheckingResult,
        text: String,
        to result: NSMutableAttributedString,
        font: UIFont,
        color: UIColor
    ) {
        guard let urlRange = Range(match.range(at: 1), in: text),
              let textRange = Range(match.range(at: 2), in: text) else { return }

        let url = String(text[urlRange])
        let linkText = String(text[textRange])

        var linkAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]

        linkAttributes[.init("CustomLinkURL")] = url

        let attributedString = NSAttributedString(string: linkText, attributes: linkAttributes)
        result.append(attributedString)
    }
}
