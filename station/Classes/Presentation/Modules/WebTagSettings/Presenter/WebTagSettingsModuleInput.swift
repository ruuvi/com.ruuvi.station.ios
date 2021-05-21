import Foundation

protocol WebTagSettingsModuleInput: AnyObject {
    func configure(webTag: WebTagRealm,
                   temperature: Temperature?)
}
