import Foundation

extension NSObjectProtocol {
    func invalidate() {
        NotificationCenter
            .default
            .removeObserver(self)
    }
}
