import XCTest
@testable import station

final class TextEditingContractTests: XCTestCase {
    func testNativeTextRangesReplaceUnicodeAtUTF16Offsets() {
        XCTAssertEqual("abc".replace(with: "X", in: NSRange(location: 1, length: 1)), "aXc")
        XCTAssertEqual("🌿é".replace(with: "A", in: NSRange(location: 2, length: 1)), "🌿A")
        XCTAssertEqual("🌿".replace(with: "!", in: NSRange(location: 2, length: 0)), "🌿!")
        XCTAssertEqual("e\u{301}🌿".replace(with: "A", in: NSRange(location: 2, length: 2)), "e\u{301}A")
        XCTAssertEqual("".replace(with: "new", in: NSRange(location: 0, length: 0)), "new")
        XCTAssertNil("abc".replace(with: "X", in: NSRange(location: 4, length: 0)))
    }

    func testOccurrenceHelpersKeepUnmatchedTextAndOnlyReplaceTheRequestedOccurrence() {
        XCTAssertEqual("🌿 A 🌿 A".replacingFirstOccurrence(of: "🌿", with: "B"), "B A 🌿 A")
        XCTAssertEqual("🌿 A 🌿 A".replacingLastOccurrence(of: "🌿", with: "B"), "🌿 A B A")
        XCTAssertEqual("abc".replacingFirstOccurrence(of: "missing", with: "X"), "abc")
        XCTAssertEqual("abc".replacingLastOccurrence(of: "missing", with: "X"), "abc")
        XCTAssertEqual("A A".replace("A", with: "B"), "B B")
    }

    func testInvalidNativeRangesAreRejectedWithoutOverflowOrAnObjectiveCException() {
        for range in [
            NSRange(location: -1, length: 1), NSRange(location: 0, length: -1),
            NSRange(location: NSNotFound, length: 1), NSRange(location: 1, length: Int.max),
            NSRange(location: 2, length: 2),
        ] {
            XCTAssertNil("abc".replace(with: "X", in: range))
        }
    }

    func testNumericInputUsesTheCurrentDecimalLocaleAndRetainsInvalidInputFallbacks() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        let decimal = formatter.string(from: 12.5)!
        XCTAssertEqual((" \n" + decimal + "\t").doubleValue, 12.5)
        XCTAssertEqual("not a number".doubleValue, 0)
        XCTAssertEqual("-12".intValue, -12)
        XCTAssertNil("1.5".intValue)
        XCTAssertNil("999999999999999999999999999".intValue)
    }
}
