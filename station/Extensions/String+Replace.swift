import Foundation

extension String {
    func replace(with text: String, in range: NSRange) -> String? {
        guard range.location + range.length <= self.count else { return nil }
        return (self as NSString).replacingCharacters(in: range, with: text)
    }
}
