import Foundation

extension String {
    static let nbsp = "\u{00a0}"
}

extension String? {
    func hasText() -> Bool {
        if let self, !self.isEmpty {
            true
        } else {
            false
        }
    }
}
