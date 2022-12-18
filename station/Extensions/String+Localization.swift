import Foundation

extension String {
    func localilized() -> String {
        return NSLocalizedString(self, comment: self)
    }
}
