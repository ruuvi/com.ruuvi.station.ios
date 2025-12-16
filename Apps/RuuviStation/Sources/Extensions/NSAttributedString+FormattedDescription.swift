// swiftlint:disable file_length

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
    case list(level: Int)

    var isList: Bool {
        if case .list = self { return true }
        return false
    }

    var isTitle: Bool {
        if case .title = self { return true }
        return false
    }
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

    // swiftlint:disable:next function_parameter_count function_body_length cyclomatic_complexity
    static func processFormattedText(
        _ text: String,
        titleFont: UIFont,
        paragraphFont: UIFont,
        boldFont: UIFont,
        titleColor: UIColor,
        paragraphColor: UIColor,
        linkColor: UIColor,
        linkFont: UIFont,
        allowLists: Bool = true
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remainingText = text

        let titleRegex = createTitleRegex()
        let boldRegex = createBoldRegex()
        let linkRegex = createLinkRegex()
        let listRegex = allowLists ? createListRegex() : nil

        var previousMatchType: MatchType?

        while !remainingText.isEmpty {
            guard let nextMatch = findNextMatch(
                in: remainingText,
                titleRegex: titleRegex,
                boldRegex: boldRegex,
                linkRegex: linkRegex,
                listRegex: listRegex
            ) else {
                appendRemainingText(
                    remainingText,
                    to: result,
                    font: paragraphFont,
                    color: paragraphColor
                )
                break
            }

            let (match, matchType) = nextMatch
            let nsString = remainingText as NSString

            // Get the text before the match
            let beforeTagRange = NSRange(location: 0, length: match.range.location)
            let beforeTagText = nsString.substring(with: beforeTagRange)

            // Check if this is the first list item in a section
            // A new list section starts after: beginning, title, non-list element,
            // OR when there's non-whitespace text between this and previous list item
            let isFirstListInSection: Bool = {
                guard matchType.isList else { return false }

                if previousMatchType == nil || previousMatchType?.isTitle == true ||
                    previousMatchType?.isList == false {
                    return true
                }

                // Previous was a list - check if there's non-whitespace text between
                if previousMatchType?.isList == true {
                    let textWithoutNewlines = beforeTagText.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    if !textWithoutNewlines.isEmpty {
                        return true
                    }
                }

                return false
            }()

            // Handle newlines before first list item in section
            if isFirstListInSection && allowLists {
                let (textToAppend, _) = textAndTrailingNewlineCount(beforeTagText)

                // Append text without trailing newlines
                appendRemainingText(
                    textToAppend,
                    to: result,
                    font: paragraphFont,
                    color: paragraphColor
                )

                // Add 2 newlines before first list item only if there's content before it
                let hasContentBefore = !textToAppend.isEmpty || result.length > 0
                if hasContentBefore {
                    result.append(NSAttributedString(
                        string: "\n\n",
                        attributes: [.font: paragraphFont, .foregroundColor: paragraphColor]
                    ))
                }
            } else {
                appendTextBeforeMatch(
                    nsString: nsString,
                    match: match,
                    to: result,
                    font: paragraphFont,
                    color: paragraphColor
                )
            }

            // Look ahead to determine if this is the last list item in a section
            let textAfterMatch = nsString.substring(from: match.range.location + match.range.length)
            let nextMatchAfterCurrent = findNextMatch(
                in: textAfterMatch,
                titleRegex: titleRegex,
                boldRegex: boldRegex,
                linkRegex: linkRegex,
                listRegex: listRegex
            )

            let isLastListInSection: Bool = {
                guard matchType.isList else { return false }

                if let (nextMatchResult, nextMatchType) = nextMatchAfterCurrent {
                    // If the next match is not a list, this is the last list item in the section
                    if !nextMatchType.isList {
                        return true
                    }

                    // Next match IS a list - check if there's non-whitespace text between
                    let textBetween = (textAfterMatch as NSString)
                        .substring(to: nextMatchResult.range.location)
                    let textWithoutWhitespace = textBetween.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    if !textWithoutWhitespace.isEmpty {
                        return true
                    }

                    return false
                } else {
                    // No more matches - this is the last list item
                    return true
                }
            }()

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
            case .list(let level):
                appendListItem(
                    match: match,
                    text: remainingText,
                    to: result,
                    level: level,
                    isLastInSection: isLastListInSection,
                    titleFont: titleFont,
                    paragraphFont: paragraphFont,
                    boldFont: boldFont,
                    titleColor: titleColor,
                    paragraphColor: paragraphColor,
                    linkColor: linkColor,
                    linkFont: linkFont
                )
            }

            previousMatchType = matchType
            remainingText = nsString.substring(from: match.range.location + match.range.length)

            // Skip existing newlines after list items (we handle newlines ourselves for lists)
            if matchType.isList {
                remainingText = skipLeadingNewlines(remainingText)
            }
        }

        return result
    }

    /// Removes leading newlines from text
    static func skipLeadingNewlines(_ text: String) -> String {
        var startIndex = text.startIndex
        while startIndex < text.endIndex && text[startIndex] == "\n" {
            startIndex = text.index(after: startIndex)
        }
        return String(text[startIndex...])
    }

    /// Returns the text with trailing newlines removed, and the count of trailing newlines
    static func textAndTrailingNewlineCount(_ text: String) -> (String, Int) {
        var count = 0
        var endIndex = text.endIndex

        while endIndex > text.startIndex {
            let prevIndex = text.index(before: endIndex)
            if text[prevIndex] == "\n" {
                count += 1
                endIndex = prevIndex
            } else {
                break
            }
        }

        let trimmedText = String(text[..<endIndex])
        return (trimmedText, count)
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

    static func createListRegex() -> NSRegularExpression? {
        return try? NSRegularExpression(
            pattern: "<li([0-9]*)>(.*?)</li\\1>", options: [.dotMatchesLineSeparators]
        )
    }

    static func listLevel(from match: NSTextCheckingResult, in text: String) -> Int {
        guard let levelRange = Range(match.range(at: 1), in: text),
              let level = Int(text[levelRange]) else {
            return 1
        }
        return max(level, 1)
    }

    static func findNextMatch(
        in text: String,
        titleRegex: NSRegularExpression?,
        boldRegex: NSRegularExpression?,
        linkRegex: NSRegularExpression?,
        listRegex: NSRegularExpression?
    ) -> (NSTextCheckingResult, MatchType)? {
        let range = NSRange(location: 0, length: text.utf16.count)

        let titleMatch = titleRegex?.firstMatch(in: text, range: range)
        let boldMatch = boldRegex?.firstMatch(in: text, range: range)
        let linkMatch = linkRegex?.firstMatch(in: text, range: range)
        let listMatch = listRegex?.firstMatch(in: text, range: range)

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

        if let list = listMatch {
            let level = listLevel(from: list, in: text)
            if earliestMatch == nil || list.range.location < earliestMatch!.0.range.location {
                earliestMatch = (list, .list(level: level))
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

    // swiftlint:disable:next function_parameter_count
    static func appendListItem(
        match: NSTextCheckingResult,
        text: String,
        to result: NSMutableAttributedString,
        level: Int,
        isLastInSection: Bool,
        titleFont: UIFont,
        paragraphFont: UIFont,
        boldFont: UIFont,
        titleColor: UIColor,
        paragraphColor: UIColor,
        linkColor: UIColor,
        linkFont: UIFont
    ) {
        guard let listRange = Range(match.range(at: 2), in: text) else { return }

        let listContent = String(text[listRange])
        let formattedContent = processFormattedText(
            listContent,
            titleFont: titleFont,
            paragraphFont: paragraphFont,
            boldFont: boldFont,
            titleColor: titleColor,
            paragraphColor: paragraphColor,
            linkColor: linkColor,
            linkFont: linkFont,
            allowLists: false
        )

        let bulletSymbol = bulletSymbol(for: level)
        let bulletPrefix = "\(bulletSymbol) "
        let tabWidth = "    ".size(withAttributes: [.font: paragraphFont]).width
        let indentWidth = tabWidth * CGFloat(max(level - 1, 0))
        let bulletPrefixWidth = bulletPrefix.size(withAttributes: [.font: paragraphFont]).width

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = indentWidth
        paragraphStyle.headIndent = indentWidth + bulletPrefixWidth

        let listAttributes: [NSAttributedString.Key: Any] = [
            .font: paragraphFont,
            .foregroundColor: paragraphColor,
            .paragraphStyle: paragraphStyle,
        ]

        let listItem = NSMutableAttributedString(
            string: bulletPrefix, attributes: listAttributes
        )
        listItem.append(formattedContent)
        listItem
            .addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(
                    location: 0,
                    length: listItem.length
                )
            )

        if isLastInSection {
            // For the last list item in a section, always add 2 newlines
            // (existing newlines in source will be consumed/skipped in the main loop)
            listItem.append(NSAttributedString(string: "\n\n", attributes: listAttributes))
        } else {
            // For middle list items, always add exactly 1 newline
            // (existing newlines in source will be consumed/skipped in the main loop)
            listItem.append(NSAttributedString(string: "\n", attributes: listAttributes))
        }

        result.append(listItem)
    }

    static func bulletSymbol(for level: Int) -> String {
        switch level {
        case 1:
            return "•"
        default:
            return "◦"
        }
    }
}

// swiftlint:enable file_length
