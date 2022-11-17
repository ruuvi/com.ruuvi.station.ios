import Foundation

extension String {
    static let nbsp = "\u{00a0}"
}

extension Optional where Wrapped == String {
    func hasText() -> Bool {
        if let self = self, !self.isEmpty {
            return true
        } else {
            return false
        }
    }
}
