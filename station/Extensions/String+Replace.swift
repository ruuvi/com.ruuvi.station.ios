import Foundation

extension String {
    func replace(with text: String, in range: NSRange) -> String? {
        guard range.location + range.length <= self.count else { return nil }
        return (self as NSString).replacingCharacters(in: range, with: text)
    }

    func replace(_ text: String, with replacementText: String) -> String {
        return replacingOccurrences(of: text, with: replacementText)
    }
}

extension String {
    static let numberFormatter = NumberFormatter()
    var doubleValue: Double {
        String.numberFormatter.decimalSeparator = "."
        if let result =  String.numberFormatter.number(from: self) {
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
