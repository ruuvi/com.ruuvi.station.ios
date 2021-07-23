import Foundation

public protocol Localizable: AnyObject {
    func localize()
}

extension Localizable {
    public func setupLocalization() {
        LocalizationService.shared.add(localizable: self)
    }
}
