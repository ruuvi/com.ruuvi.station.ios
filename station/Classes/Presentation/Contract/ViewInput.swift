import Foundation

protocol ViewInput: Themeable, Localizable {
    
}

extension ViewInput {
    func setupLocalization() {
        LocalizationService.shared.add(localizable: self)
    }
}
