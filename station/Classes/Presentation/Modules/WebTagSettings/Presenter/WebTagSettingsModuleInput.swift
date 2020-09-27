import Foundation

protocol WebTagSettingsModuleInput: class {
    func configure(webTag: WebTagRealm,
                   temperature: Temperature?)
}
