import Foundation
import RuuviOntology

protocol WebTagSettingsModuleInput: AnyObject {
    func configure(webTag: WebTagRealm,
                   temperature: Temperature?)
}
