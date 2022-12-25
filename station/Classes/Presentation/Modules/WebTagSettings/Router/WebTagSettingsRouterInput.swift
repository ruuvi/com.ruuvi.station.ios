import Foundation
import RuuviOntology

protocol WebTagSettingsRouterInput {
    func dismiss()
    func openLocationPicker(output: LocationPickerModuleOutput)
    func openSettings()
    func openBackgroundSelectionView(virtualSensor: VirtualTagSensor)
}
