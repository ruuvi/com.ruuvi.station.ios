import UIKit
import XCTest
@testable import RuuviCore

@MainActor final class FormattedDescriptionTests: XCTestCase {
    func testTitlesBoldLinksAndUnicodeRetainTextAndAttributes() throws {
        let result = format(
            "🌡️ [title]Temperature[/title]\\nPlain [b]bold 🦫[/b] and "
                + "[link url=\"https://ruuvi.com/ä?x=1&y=2\"]guide 🔗[/link]."
        )
        XCTAssertEqual(result.string, "🌡️ Temperature\nPlain bold 🦫 and guide 🔗.")
        let source = result.string as NSString
        XCTAssertEqual(
            result.attribute(.font, at: source.range(of: "Temperature").location, effectiveRange: nil) as? UIFont,
            UIFont.systemFont(ofSize: 22, weight: .bold))
        XCTAssertEqual(
            result.attribute(.font, at: source.range(of: "bold").location, effectiveRange: nil) as? UIFont,
            UIFont.boldSystemFont(ofSize: 14))
        XCTAssertEqual(
            result.attribute(
                .init("CustomLinkURL"), at: source.range(of: "guide").location,
                effectiveRange: nil) as? String, "https://ruuvi.com/ä?x=1&y=2")
        XCTAssertEqual(
            result.attribute(
                .foregroundColor, at: source.range(of: "guide").location,
                effectiveRange: nil) as? UIColor, .blue)
        XCTAssertEqual(format("&lt;b&gt;bold&lt;/b&gt;").string, "bold")
        XCTAssertEqual(format("").length, 0)
        XCTAssertEqual(format("Unclosed <b>text").string, "Unclosed <b>text")
    }

    func testListLevelsSpacingAndNestedFormattingArePreserved() throws {
        let result = format(
            "<title>Advice</title>\n\n<li>First <b>important</b> item</li>\n"
                + "<li2>Nested <link url=https://ruuvi.com>link</link></li2>\n"
                + "<li>Last item</li>\n\nAfter."
        )
        XCTAssertEqual(result.string, "Advice\n\n• First important item\n◦ Nested link\n• Last item\n\nAfter.")
        let text = result.string as NSString
        let outer = try XCTUnwrap(
            result.attribute(
                .paragraphStyle, at: text.range(of: "First").location,
                effectiveRange: nil) as? NSParagraphStyle)
        let inner = try XCTUnwrap(
            result.attribute(
                .paragraphStyle, at: text.range(of: "Nested").location,
                effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(outer.firstLineHeadIndent, 0)
        XCTAssertGreaterThan(outer.headIndent, 0)
        XCTAssertGreaterThan(inner.firstLineHeadIndent, outer.firstLineHeadIndent)
        XCTAssertEqual(
            result.attribute(
                .font, at: text.range(of: "important").location,
                effectiveRange: nil) as? UIFont, UIFont.boldSystemFont(ofSize: 14))
        XCTAssertEqual(
            result.attribute(
                .init("CustomLinkURL"), at: text.range(of: "link").location,
                effectiveRange: nil) as? String, "https://ruuvi.com")
        XCTAssertEqual(format("<li0>zero</li0><li3>deep</li3>").string, "• zero\n◦ deep\n\n")
        XCTAssertEqual(
            format("<li>one</li>Between<li>two</li><b>end</b>").string,
            "• one\n\nBetween\n\n• two\n\nend")
        XCTAssertEqual(
            format("<b>Intro</b><li>line\nbreak</li><title>Next</title><li>last</li>").string,
            "Intro\n\n• line\nbreak\n\nNext\n\n• last\n\n")
    }

    private func format(_ text: String) -> NSAttributedString {
        .fromFormattedDescription(
            text, titleFont: .systemFont(ofSize: 22, weight: .bold),
            paragraphFont: .systemFont(ofSize: 14), boldFont: .boldSystemFont(ofSize: 14),
            titleColor: .black, paragraphColor: .gray, linkColor: .blue, linkFont: .italicSystemFont(ofSize: 14)
        )
    }
}
