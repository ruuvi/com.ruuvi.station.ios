import UIKit

extension NSAttributedString {

    static func fromFormattedDescription(
        _ escapedHTML: String,
        titleFont: UIFont,
        paragraphFont: UIFont,
        titleColor: UIColor,
        paragraphColor: UIColor
    ) -> NSAttributedString {
        let unescapedText = unescapeHTML(escapedHTML)

        return processFormattedText(
            unescapedText,
            titleFont: titleFont,
            paragraphFont: paragraphFont,
            titleColor: titleColor,
            paragraphColor: paragraphColor
        )
    }
}

// MARK: - Private Processing Methods
private extension NSAttributedString {

    static func unescapeHTML(_ escapedHTML: String) -> String {
        return escapedHTML
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    static func processFormattedText(
        _ text: String,
        titleFont: UIFont,
        paragraphFont: UIFont,
        titleColor: UIColor,
        paragraphColor: UIColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remainingText = text

        let titleRegex = createTitleRegex()
        let linkRegex = createLinkRegex()

        while !remainingText.isEmpty {
            guard let nextMatch = findNextMatch(
                in: remainingText,
                titleRegex: titleRegex,
                linkRegex: linkRegex
            ) else {
                appendRemainingText(remainingText, to: result, font: paragraphFont, color: paragraphColor)
                break
            }

            let (match, isTitle) = nextMatch
            let nsString = remainingText as NSString

            appendTextBeforeMatch(
                nsString: nsString,
                match: match,
                to: result,
                font: paragraphFont,
                color: paragraphColor
            )

            if isTitle {
                appendTitleText(
                    match: match,
                    text: remainingText,
                    to: result,
                    font: titleFont,
                    color: titleColor
                )
            } else {
                appendLinkText(
                    match: match,
                    text: remainingText,
                    to: result,
                    font: paragraphFont,
                    color: paragraphColor
                )
            }

            remainingText = nsString.substring(from: match.range.location + match.range.length)
        }

        return result
    }

    static func createTitleRegex() -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: "<title>(.*?)</title>", options: [])
    }

    static func createLinkRegex() -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: "<link url=\"(.*?)\">(.*?)</link>", options: [])
    }

    static func findNextMatch(
        in text: String,
        titleRegex: NSRegularExpression?,
        linkRegex: NSRegularExpression?
    ) -> (NSTextCheckingResult, Bool)? {
        let range = NSRange(location: 0, length: text.utf16.count)
        let titleMatch = titleRegex?.firstMatch(in: text, range: range)
        let linkMatch = linkRegex?.firstMatch(in: text, range: range)

        if let title = titleMatch, let link = linkMatch {
            return title.range.location < link.range.location ? (title, true) : (link, false)
        } else if let title = titleMatch {
            return (title, true)
        } else if let link = linkMatch {
            return (link, false)
        }

        return nil
    }

    static func appendRemainingText(
        _ text: String,
        to result: NSMutableAttributedString,
        font: UIFont,
        color: UIColor
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

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

        let trimmedText = beforeTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

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
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]

        linkAttributes[.init("CustomLinkURL")] = url

        let attributedString = NSAttributedString(string: linkText, attributes: linkAttributes)
        result.append(attributedString)
    }
}
