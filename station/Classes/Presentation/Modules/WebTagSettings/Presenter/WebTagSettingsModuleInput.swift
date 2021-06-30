import Foundation
import RuuviOntology

protocol WebTagSettingsModuleInput: AnyObject {
    func configure(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    )
}
