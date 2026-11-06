import Foundation

/// Validates the resulting text, including paste and replacement edits, while
/// allowing incomplete signed decimals during typing.
enum AlertDecimalInput {
    static func allows(text: String, range: NSRange, replacement: String, decimalSeparator: String) -> Bool {
        guard let range = Range(range, in: text), !decimalSeparator.isEmpty else { return false }
        var candidate = text.replacingCharacters(in: range, with: replacement)
        if candidate.hasPrefix("-") { candidate.removeFirst() }
        let components = candidate.components(separatedBy: decimalSeparator)
        guard components.count <= 2 else { return false }
        guard components.allSatisfy({ $0.allSatisfy { $0 >= "0" && $0 <= "9" } }) else { return false }
        return components.count == 1 || components[1].count <= 2
    }
}
