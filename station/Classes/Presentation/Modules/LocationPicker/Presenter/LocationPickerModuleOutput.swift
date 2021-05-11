import Foundation

protocol LocationPickerModuleOutput: AnyObject {
    func locationPicker(module: LocationPickerModuleInput, didPick location: Location)
}
