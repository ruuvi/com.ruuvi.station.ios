import Foundation

protocol LocationPickerModuleOutput: class {
    func locationPicker(module: LocationPickerModuleInput, didPick location: Location)
}
