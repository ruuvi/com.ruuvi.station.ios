import Foundation

protocol Localizable: AnyObject {
    func localize()
}

extension Localizable {
    func setupLocalization() {
        LocalizationService.shared.add(localizable: self)
    }
}
