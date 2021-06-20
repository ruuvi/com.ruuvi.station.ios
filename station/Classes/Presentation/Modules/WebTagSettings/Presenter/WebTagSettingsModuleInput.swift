import Foundation
import RuuviOntology
import RuuviVirtual

protocol WebTagSettingsModuleInput: AnyObject {
    func configure(
        webTag: WebTagRealm,
        temperature: Temperature?
    )
}
