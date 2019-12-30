import Foundation

protocol Localizable: class {
    func localize()
}

extension Localizable {
    func setupLocalization() {
        LocalizationService.shared.add(localizable: self)
    }
}
