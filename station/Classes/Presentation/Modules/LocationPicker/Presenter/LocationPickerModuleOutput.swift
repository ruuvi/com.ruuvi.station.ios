import Foundation
import RuuviOntology

protocol LocationPickerModuleOutput: AnyObject {
    func locationPicker(module: LocationPickerModuleInput, didPick location: Location)
}
