import Foundation

extension NSObjectProtocol {
    func invalidate() {
        // swiftlint:disable:next notification_center_detachment
        NotificationCenter
            .default
            .removeObserver(self)
    }
}
