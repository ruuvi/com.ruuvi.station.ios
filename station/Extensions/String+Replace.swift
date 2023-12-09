import Foundation

extension String {
    func replace(with text: String, in range: NSRange) -> String? {
        guard range.location + range.length <= count else { return nil }
        return (self as NSString).replacingCharacters(in: range, with: text)
    }

    func replace(_ text: String, with replacementText: String) -> String {
        replacingOccurrences(of: text, with: replacementText)
    }
}

extension String {
    static let numberFormatter = NumberFormatter()
    var doubleValue: Double {
        String.numberFormatter.decimalSeparator = "."
        if let result = String.numberFormatter.number(from: self) {
            return result.doubleValue
        } else {
            String.numberFormatter.decimalSeparator = ","
            if let result = String.numberFormatter.number(from: self) {
                return result.doubleValue
            }
        }
        return 0
    }
}

extension String {
    var intValue: Int? {
        Int(self)
    }
}

extension String {
    func replacingFirstOccurrence(of target: String, with replacement: String) -> String {
        guard let range = range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }

    func replacingLastOccurrence(of target: String, with replacement: String) -> String {
        let options: String.CompareOptions = [.backwards]
        if let range = range(of: target,
                             options: options,
                             range: nil,
                             locale: nil)
        {
            return replacingCharacters(in: range, with: replacement)
        }
        return self
    }
}
